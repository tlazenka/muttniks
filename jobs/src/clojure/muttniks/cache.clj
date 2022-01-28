(ns muttniks.cache
  (:require
    [taoensso.carmine :as car :refer (wcar)]
    ))

(def server1-conn {:pool {} :spec {
                                   :uri (or (System/getenv "REDIS_URL") "redis")
							   }
                   })

(defmacro wcar* [& body] `(car/wcar server1-conn ~@body))

(defn cache-set [key value]
  (wcar*
    (car/set key value)))

(defn cache-get [key]
  (wcar*
    (car/get key))
)
