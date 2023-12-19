FROM debian:bullseye-slim

RUN apt-get update && apt-get install -y \
    bash vim nano rclone fuse python3 python3-pip python3-venv \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /rclone

COPY . /rclone/

# DO NOT MODIFY BELOW THIS LINE!

ENV APP_USERNAME=""
ENV APP_GROUP=""
ENV RCLONE_CONFIG_PATH=""
ENV RCLONE_USERNAME=""
ENV RCLONE_PASSWORD=""

RUN python3 -m venv /venv && \
    . /venv/bin/activate && \
    pip install --no-cache-dir -r requirements.txt

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
