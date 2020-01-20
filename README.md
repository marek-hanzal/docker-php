# docker-php
Simple PHP docker image.

Services are controlled with `supervisord`.

- Nginx running on port `80`
- PHP-FPM running on port `9000`
- OpenSSHH server running on port `22`
    - login with `root:1234`

This image is intended for `development use` (as this is all-in-one solution).
