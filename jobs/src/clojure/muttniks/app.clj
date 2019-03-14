(ns muttniks.app
  (:import
    (helpers Web3jHelpers)
    (java.math BigInteger)
    )
  (:require
    [ring.adapter.jetty :as jetty]
    [compojure.core :refer [defroutes GET]]
    [muttniks.helpers :as muttnik-helpers]
    [muttniks.cache :as muttnik-cache]
    [muttniks.scheduler :as muttnik-scheduler]
    [muttniks.api :as muttnik-api]
    [cheshire.core :as chesh])
  (:use [clojurewerkz.quartzite.jobs :only [defjob]]))

(defroutes handler
           (GET "/lastUpdateTime" []
             (let [last-update-time (muttnik-cache/cache-get "last-update-time")]
               {:status 200
                :headers {"Access-Control-Allow-Origin" "*", "Content-Type" "application/json"}
                :body (chesh/generate-string {:lastUpdateTime (muttnik-helpers/string->long last-update-time)})
                }))
           (GET "/petName/:externalId" [externalId]
             (let [name (muttnik-cache/cache-get externalId)
                   last-update-time (muttnik-cache/cache-get "last-update-time")]
               {:status 200
                :headers {"Access-Control-Allow-Origin" "*", "Content-Type" "application/json"}
                :body (chesh/generate-string {:name name
                                              :lastUpdateTime (muttnik-helpers/string->long last-update-time)
                                              })
                }))
           (GET "/uncachedPetName/:externalId" [externalId]
             (let [name (.trim (Web3jHelpers/getLastAssignedName (read-string externalId)))]
               {:status 200
                :headers {"Access-Control-Allow-Origin" "*", "Content-Type" "application/json"}
                :body (chesh/generate-string {:name name})
                }))
           )

(defn update-cache [num-pets start-block end-block]
  (let [f (fn [external-id]
            (when-let [name (Web3jHelpers/getLastAssignedName start-block end-block external-id)]
              (println "External id: " external-id " New name: " name)
              (muttnik-cache/cache-set external-id (.trim name))))]
    (doall (pmap f (range 1 (+ num-pets 1))))))

(defjob PollJob [ctx]
  (let [last-block-queried (or (muttnik-cache/cache-get "last-block-queried") "0")
        start-block (BigInteger. last-block-queried)
        end-block (Web3jHelpers/getLatestBlockNumber)]
    (when (not= start-block end-block)
      (let [update-time (.getTime (java.util.Date.))
            num-pets (muttnik-api/get-number-of-pets)]
        (println "*** Start update cache")
        (println "Start block: " start-block " End block: " end-block)
        (update-cache (Integer. num-pets) start-block end-block)
        (muttnik-cache/cache-set "last-block-queried" (.toString end-block))
        (muttnik-cache/cache-set "last-update-time" update-time)
        (println "*** End update cache")))))

(defn -main []
  (println "Starting jetty")
  (jetty/run-jetty handler
                   {:port (Integer. (or (System/getenv "PORT") 5000))
                    :join? false})
  (println "Initializing scheduler")
  (muttnik-scheduler/initialize-scheduler)
  (println "Scheduling job")
  (muttnik-scheduler/schedule-job-with-seconds-interval PollJob (Integer. (or (System/getenv "NAME_CHANGE_POLL_INTERVAL_SECONDS") (* 5 60))))
)
