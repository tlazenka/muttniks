(ns muttniks.web3
  (:require
    [clj-http.client :as client]
    [cheshire.core :as chesh]
    [muttniks.helpers :refer (to-hex-string unhexify)]
    ))

(def base-url-json-rpc (or (System/getenv "JSON_RPC_BASE_URL") "http://ganache:7545"))

(defn get-latest-block []
  (get-in (chesh/parse-string
            (get-in (client/post base-url-json-rpc
                                 {:body
                                          (chesh/generate-string
                                            {:id 1
                                             :jsonrpc "2.0"
                                             :method "eth_blockNumber"
                                             }
                                            )
                                  :accept :json})
                    [:body]) true)
          [:result]))

(defn pet-name-request-payload [external-id to-block]

  {
   :id 1
   :jsonrpc "2.0"
   :method "eth_getLogs"
   :params [
            {
             :fromBlock "0x0"
             :toBlock   to-block
             :address   (or (System/getenv "ETH_ADOPTION_CONTRACT_ADDRESS") "0x345ca3e014aaf5dca488057592ee47305d9b3e10")
             :topics    [(or (System/getenv "ETH_NAME_ASSIGNED_TOPIC") "0x81c1028a0bee463ceacb9e56ba0383394952457da330ba49947c730dd72255b5"),
                         (to-hex-string external-id 64)]
             }
            ]
   }
  )

(defn get-pet-name-payload [external-id to-block]
  (chesh/parse-string
    (get-in (client/post base-url-json-rpc
                         {:body (chesh/generate-string (pet-name-request-payload external-id to-block)) }
                         :accept :json
                         ) [:body])
    true))

(defn get-pet-name-payload-body [external-id to-block]
  (get-in (get-pet-name-payload external-id to-block) [:result]))

(defn get-last-pet-name-data [external-id to-block]
  (let [payload (get-pet-name-payload-body external-id to-block)]
    (get-in (last payload) [:data])))

(defn get-last-pet-name-hex [external-id to-block]
  (let [data (get-last-pet-name-data external-id to-block)
        length (.length data)
        name-in-hex (subs data (- length 64) length)]
    name-in-hex))

(defn get-last-pet-name-string [external-id to-block]
  (let [name-in-hex (get-last-pet-name-hex external-id to-block)]
    (unhexify name-in-hex)))

