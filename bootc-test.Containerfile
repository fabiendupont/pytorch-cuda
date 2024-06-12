# vim: syntax=dockerfile expandtab tabstop=4 shiftwidth=4
FROM registry.redhat.io/rhel9/rhel-bootc:9.4 AS builder

COPY epel.repo /etc/yum.repos.d/epel.repo
COPY RPM-GPG-KEY-EPEL-9 /etc/pki/rpm-gpg/RPM-GPG-KEY-EPEL-9

RUN rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-EPEL-9 && \
    dnf -y install --nobest --nodocs --setopt=install_weak_deps=False --enablerepo=codeready-builder-for-rhel-9-x86_64-rpms \
        ccache && \
    dnf clean all
