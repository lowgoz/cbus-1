# This Dockerfile sets up cmqttd, which bridges a C-Bus PCI to a MQTT server.
#
# This requires about 120 MiB of dependencies, and the
# The final image size is about 100 MiB.
#
# Example use:
#
# $ docker build -t cmqttd .
# $ docker run --device /dev/ttyUSB0 -e "SERIAL_PORT=/dev/ttyUSB0" \
#     -e "MQTT_SERVER=192.2.0.1" -e "TZ=Australia/Adelaide" -it cmqttd

FROM alpine:3.11 as base

# Install most Python deps here, because that way we don't need to include build tools in the
# final image.
RUN apk add --no-cache python3 py3-cffi py3-paho-mqtt py3-six tzdata && \
    pip3 install 'pyserial==3.4' 'pyserial_asyncio==0.4'

# Runs tests and builds a distribution tarball
FROM base as builder
# See also .dockerignore
ADD . /cbus
WORKDIR /cbus
RUN pip3 install 'parameterized' && \
    python3 -m unittest && \
    python3 setup.py bdist -p generic --format=gztar

# cmqttd runner image
FROM base as cmqttd
COPY COPYING COPYING.LESSER Dockerfile README.md entrypoint-cmqttd.sh /
COPY --from=builder /cbus/dist/cbus-0.2.generic.tar.gz /
RUN tar zxf /cbus-0.2.generic.tar.gz && rm /cbus-0.2.generic.tar.gz
COPY pw /
# Runs cmqttd itself
#CMD /entrypoint-cmqttd.sh
CMD echo "Local time zone: ${TZ:-UTC}" && \
#    echo -n "Current time: " && date -R && \
    cmqttd -b 192.168.1.3 -t 192.168.1.8:10001 --broker-disable-tls --broker-auth pw  #this works fine - but it doesn't seem to call the entrypoint-smqttd.sh - cmqttd is butied in the subfolder structure
