(defproject clojure-muttniks "1.0.1"
  :description "Muttniks Clojure Web App"
  :dependencies [
                 [org.clojure/clojure "1.6.0"]
                 [compojure "1.4.0"]
                 [ring/ring-jetty-adapter "1.4.0"]
                 [clojurewerkz/quartzite "1.1.0"]
                 [com.taoensso/carmine "2.19.1"]
                 [cheshire "5.8.1"]
                 [clj-http "3.9.1"]
                 [org.web3j/core "3.3.1"]
                 ]
  :repl-options {
                 ;; Default 30000 (30 seconds)
                 :timeout 120000
                 }
  :min-lein-version "2.0.0"
  :source-paths ["src/clojure"]
  :java-source-paths ["src/java"]
  :test-paths ["test/clojure"]
  :main ^:skip-aot muttniks.app)
