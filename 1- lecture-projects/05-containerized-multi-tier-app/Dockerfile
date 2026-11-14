# =====================================================
# Stage 1: Build vProfile WAR using Maven
# =====================================================
# FROM maven:3.9.16-eclipse-temurin-11 AS build
FROM maven:3.9.6-eclipse-temurin-17 AS build

LABEL stage="vprofile-build"

WORKDIR /build

# Copy Maven project definition
COPY pom.xml .

# Copy application source
COPY src ./src

# Build the application and generate WAR
# Run tests, just like your original deployment script
RUN mvn -B clean package

# Validate generated WAR
RUN test -s target/vprofile-v2.war


# =====================================================
# Stage 2: Deploy WAR using Tomcat
# =====================================================
FROM tomcat:9-jre11 AS runtime

LABEL maintainer="DevOps Learning Project"
LABEL application="vProfile"

# Remove default Tomcat applications
RUN rm -rf /usr/local/tomcat/webapps/*

# Copy WAR from Maven build stage
COPY --from=build \
    /build/target/vprofile-v2.war \
    /usr/local/tomcat/webapps/ROOT.war

# Tomcat HTTP port
EXPOSE 8080

# Run Tomcat in foreground
CMD ["catalina.sh", "run"]
