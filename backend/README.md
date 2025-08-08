# Postgres Agentic Shop

## Project Overview
Postgres Agentic Shop backend system is designed to demonstrate an AI-powered retail solution using PostgreSQL and agent-based architecture.

## Getting Started

### Prerequisites
- Docker installed on your machine


### Running the Server

1. **Clone the repository:**
    ```sh
    cd postgres-agentic-shop/backend
    ```

2. **Build and run the Docker containers:**
    ```sh
    docker build . -t be-agentic-shop
    docker run -d -p 8000:8000 --name agentic-shop-api be-agentic-shop
    ```

3. **Access the application:**
    Once the container is up and running, you can access the application at `http://localhost:8000`.

### Stopping the Server
To stop the server and remove the container, run:
```sh
docker container stop agentic-shop-api
docker rm agentic-shop-api
```
