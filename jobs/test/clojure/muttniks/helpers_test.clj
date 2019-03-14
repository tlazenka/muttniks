(ns muttniks.helpers-test
  (:use clojure.test)
  (:import
    (helpers Web3jHelpers)
    (org.web3j.protocol.core.methods.response EthLog$LogObject)
    )
  (:require
    [muttniks.helpers :as muttnik-helpers]
    )
  )

(deftest helpers-test
  (is (= (muttnik-helpers/string->long "5") 5))
  (is (nil? (muttnik-helpers/string->long "a")))
  (is (nil? (muttnik-helpers/string->long "5.3")))
  (is (= (muttnik-helpers/to-hex-string 1 64) "0x0000000000000000000000000000000000000000000000000000000000000001"))
  (is (= (muttnik-helpers/to-hex-string 20 64) "0x0000000000000000000000000000000000000000000000000000000000000014"))
  (is (= (muttnik-helpers/to-hex-string 1 2) "0x01"))
  (is (= (muttnik-helpers/to-hex-string 20 2) "0x14"))
  (is (= (muttnik-helpers/unhexify "537472656c6b61") "Strelka"))
  (is (= (muttnik-helpers/unhexify "417374726f") "Astro"))
  )

(deftest web3j-helpers-test
  (let [log
        (EthLog$LogObject.
          false
          "0x00"
          "0x00"
          "0xbb173bc01572d8deb9f1792094f7a5684470c055e31fe8ebcdf6458233b1057b"
          "0xfc7c163ca6be8691a606ced7712e9f841c1cefc5b187fdae92ec3af51d69c356"
          "0x0e"
          "0x345ca3e014aaf5dca488057592ee47305d9b3e10"
          "0x417374726f000000000000000000000000000000000000000000000000000000"
          "mined"
          ["0x81c1028a0bee463ceacb9e56ba0383394952457da330ba49947c730dd72255b5", "0x0000000000000000000000000000000000000000000000000000000000000001"]
          )
        names (Web3jHelpers/getNamesFromLogResults [log])]
    (is (= (count names) 1))
    (is (= (.trim (first names)) "Astro"))
    )
  )
