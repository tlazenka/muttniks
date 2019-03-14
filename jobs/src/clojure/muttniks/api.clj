(ns muttniks.api
  (:require
    [clj-http.client :as client]
    [cheshire.core :as chesh]
    ))

(def base-api-url (or (System/getenv "PLAY_API_URL") "http://app:9000"))

(defn get-number-of-pets []
  (get (chesh/parse-string
         (get-in (client/get (str base-api-url "/api/numPets")) [:body])
         ) "numPets"
       ))
