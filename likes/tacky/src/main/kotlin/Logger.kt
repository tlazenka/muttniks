package tacky

interface Logger {
    fun didBacktrack()

    fun willRealize(goal: Term)

    fun willAttempt(clause: Term)
}
