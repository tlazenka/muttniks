FROM gradle:8.14.3-jdk21 AS likes-build
WORKDIR /workspace/likes
COPY likes/ ./
RUN gradle --no-daemon \
    :tacky:publishMavenJavaPublicationToEmbeddedRepository \
    :service:publishMavenJavaPublicationToEmbeddedRepository

FROM sbtscala/scala-sbt:eclipse-temurin-21.0.12_8_1.13.0_3.3.8

WORKDIR /workspace/app
COPY --from=likes-build /workspace/likes/build/repo /workspace/maven-repo
COPY app/ ./

EXPOSE 9000
CMD ["sbt", "muttniksPlay/run"]
