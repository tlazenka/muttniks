FROM eclipse-temurin:17-jdk

RUN apt-get install -y --no-install-recommends wget

RUN wget -O /usr/local/bin/kfmt.jar \
   https://github.com/Kotlin/ktfmt/releases/download/v0.64/ktfmt-0.64-with-dependencies.jar

CMD ["java", "-jar", "/usr/local/bin/kfmt.jar", "--kotlinlang-style", "--dry-run", "--set-exit-if-changed", "."]
