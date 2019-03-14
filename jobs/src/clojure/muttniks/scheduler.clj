(ns muttniks.scheduler
  (:require
    [clojurewerkz.quartzite.scheduler :as qs]
    [clojurewerkz.quartzite.triggers :as t]
    [clojurewerkz.quartzite.jobs :as j]
    )
  (:use [clojurewerkz.quartzite.schedule.simple :only [schedule repeat-forever with-interval-in-seconds]]))

(defn initialize-scheduler []
  (qs/initialize)
  (qs/start)
)

(defn schedule-job-with-seconds-interval [job-type seconds-interval]
  (let [job (j/build
              (j/of-type job-type)
              (j/with-identity (j/key "jobs.poll.1")))
        trigger (t/build
                  (t/with-identity (t/key "triggers.1"))
                  (t/start-now)
                  (t/with-schedule (schedule
                                     (repeat-forever)
                                     (with-interval-in-seconds seconds-interval))))]
    (qs/schedule job trigger)))
