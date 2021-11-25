FROM node:17-alpine

ARG CERT_PATH

# Create app directory
WORKDIR /home/node/api

# Install app dependencies
# A wildcard is used to ensure both package.json AND package-lock.json are copied
# where available (npm@5+)
COPY package*.json ./

RUN npm install
# If you are building your code for production
# RUN npm ci --only=production

# Bundle app source
COPY . .

#get SSL-Cert
VOLUME /${CERT_PATH}
VOLUME /etc/letsencrypt

EXPOSE 443
CMD [ "node", "index.js" ]