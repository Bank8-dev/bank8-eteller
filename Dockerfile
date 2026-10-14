# SPDX-FileCopyrightText: Copyright Logically Magic Inc. <hello@logicallymagic.com>
# SPDX-FileCopyrightText: Copyright Hamid Jahanzad <Hamid@Jahanzad.com>
# SPDX-FileCopyrightText: Copyright Contributors to the Bank8:ETeller
# SPDX-License-Identifier: Apache-2.0

FROM ghcr.io/cirruslabs/flutter:3.22.3 AS builder
WORKDIR /app
COPY pubspec.yaml .
RUN flutter pub get
COPY . .
RUN flutter build web --release --no-wasm

FROM python:3.12-slim
RUN pip install --no-cache-dir static-server
WORKDIR /web
COPY --from=builder /app/build/web .
EXPOSE 3000
CMD ["static-server", "-p", "3000", "-d", "/web"]