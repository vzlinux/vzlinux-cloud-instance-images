FROM scratch
ADD vzlinux-8.5.tar.xz /
LABEL org.label-schema.schema-version="1.0"     org.label-schema.name="VzLinux 8 Base Image"     org.label-schema.vendor="Virtuozzo"     org.label-schema.license="GPLv2"     org.label-schema.build-date="20211210"
RUN yum reinstall -y vzlinux-release
CMD ["/bin/bash"]
