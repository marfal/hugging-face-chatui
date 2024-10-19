version: "3"
services:
  mongo:
    image: mongo:7
    restart: always
    volumes:
      - mongo-data:/data/db
    healthcheck:
      test: ["CMD", "mongo", "admin", "--eval", "db.adminCommand('ping')"]
      interval: 10s
      timeout: 5s
      retries: 5

  chat-ui:
    build:
      context: .
      dockerfile: Dockerfile
      args:
        INCLUDE_DB: "false"
    restart: always
    depends_on:
      mongo:
        condition: service_healthy
    ports:
      - "5173:5173"
    environment:
      - MONGODB_URL=mongodb://mongo:27017
      - OPENROUTER_API_KEY=${OPENROUTER_API_KEY}
      - OPENAI_API_KEY=${OPENAI_API_KEY}
      - ANTHROPIC_API_KEY=${ANTHROPIC_API_KEY}
    volumes:
      - ./_dotenv.local:/app/.env.local
      - chat-ui-data:/app/data

volumes:
  mongo-data:
  chat-ui-data:
