(ns muttniks.helpers)

(defn to-hex-string [number width]
  (str "0x" (format (str "%1$0" width "X") number)))

;; see https://stackoverflow.com/questions/10062967/clojures-equivalent-to-pythons-encodehex-and-decodehex
(defn unhexify [s]
  (let [bytes (into-array Byte/TYPE
                          (map (fn [[x y]]
                                 (unchecked-byte (Integer/parseInt (str x y) 16)))
                               (partition 2 s)))]
    (String. bytes "UTF-8")))

;; https://gist.github.com/borkdude/2764700
(defn string->long [number-string]
  (try (Long/parseLong number-string)
       (catch java.lang.NumberFormatException _ nil)))