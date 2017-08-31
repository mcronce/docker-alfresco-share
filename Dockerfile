FROM fedora as version_discoverer
ENV NEXUS=https://artifacts.alfresco.com/nexus/content/groups/public

RUN dnf install -y python2-pip unzip
RUN pip install --no-cache-dir mechanize cssselect lxml packaging

RUN mkdir /app
ADD assets/find_latest_version /app/
RUN \
	( \
		set -ex; \
		echo "NEXUS=\"${NEXUS}\""; \
		echo "MMT_VERSION=\"$(/app/find_latest_version "${NEXUS}/org/alfresco/alfresco-mmt")\""; \
		echo "ALF_VERSION=\"$(/app/find_latest_version "${NEXUS}/org/alfresco/share")\""; \
	) > /app/latest_versions.env

FROM tomcat:7.0-jre8
MAINTAINER Jeremie Lesage <jeremie.lesage@gmail.com>

WORKDIR /usr/local/tomcat/
COPY --from=version_discoverer /app/latest_versions.env /root/

## JAR - ALFRESCO MMT
RUN \
	set -ex && \
	. /root/latest_versions.env && \
	curl -L "${NEXUS}/org/alfresco/alfresco-mmt/${MMT_VERSION}/alfresco-mmt-${MMT_VERSION}.jar" -o /root/alfresco-mmt.jar && \
	mkdir -pv /root/amp

## SHARE.WAR
RUN \
	set -ex && \
	. /root/latest_versions.env && \
	curl -L "${NEXUS}/org/alfresco/share/${ALF_VERSION}/share-${ALF_VERSION}.war" -o "share-${ALF_VERSION}.war" && \
	unzip -q "share-${ALF_VERSION}.war" -d webapps/share && \
	rm -vf "share-${ALF_VERSION}.war" && \
	sed -i 's|^log4j.appender.File.File=.*$|log4j.appender.File.File=/usr/local/tomcat/logs/share.log|' webapps/share/WEB-INF/classes/log4j.properties && \
	mkdir -p shared/classes/alfresco/web-extension shared/lib && \
	rm -rvf /usr/share/doc webapps/docs webapps/examples webapps/manager webapps/host-manager

COPY assets/catalina.properties conf/catalina.properties
COPY assets/share-config-custom.xml shared/classes/alfresco/web-extension/share-config-custom.xml
COPY assets/server.xml conf/server.xml

ENV JAVA_OPTS " -XX:-DisableExplicitGC -Djava.security.egd=file:/dev/./urandom -Djava.awt.headless=true -Dfile.encoding=UTF-8 "

ADD assets/entrypoint.sh /opt/
ENTRYPOINT ["/opt/entrypoint.sh"]
CMD ["run"]

