FROM node:18-alpine
WORKDIR /app
COPY src/index.js .
RUN npm init -y && npm install express
EXPOSE 3000
CMD ["node", "index.js"]
