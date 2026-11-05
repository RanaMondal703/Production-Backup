FROM alpine:3.22
RUN apk add --no-cache restic rclone sqlite curl bash tzdata ca-certificates 7zip jq
COPY crontab /etc/crontabs/root
RUN chmod 600 /etc/crontabs/root
CMD ["crond", "-f", "-L", "/dev/stdout", "-l", "8"]
