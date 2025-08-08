##  AgenticShop: re-imagined shopping experience for the era of AI Agents
This repository contains a frontend application built with React, TypeScript, and Vite.

## Prerequisites
Before you begin, ensure you have the following installed:

Node.js (22.14.0)
npm (usually comes with Node.js)
Docker (optional, for container-based development)

## Local Setup Instructions

Follow these steps to set up and run the project locally:

### 1. Clone the Repository

```bash
git clone <your-repo-url>
cd postgres-agentic-shop/frontend
```

### 2. Install Dependencies

```bash
npm install
```

### 3. Configure Environment Variables

Create a `.env` file in the root directory and add the following variable:

```env
VITE_BE_APP_ENDPOINT=http://localhost:8000
```

> Adjust the `VITE_BE_APP_ENDPOINT` to match your backend API URL if it's different.

### 4. Start the Development Server

```bash
npm run dev
```

The Vite development server will typically be available at:
[http://localhost:5173](http://localhost:5173)

## Development with Docker

You can also develop using Docker by following these steps:

### 1. Build the Docker Image

```bash
docker build -t fe-agentic-shop .
```

### 2. Run the Container

```bash
docker run -p 80:80 fe-agentic-shop
```

This will serve the production build at:
[http://localhost:80](http://localhost:80)

## Available Scripts

| Command               | Description                          |
|-----------------------|--------------------------------------|
| `npm run dev`          | Start the development server        |
| `npm run build`        | Build the application for production|
| `npm run preview`      | Preview the production build locally|


## Project Structure

- **postgres-agentic-shop/frontend**
  - **public**: Static assets
  - **src**
    - **components**: Reusable UI components
    - **constants**: Reusable constants/svgs with global scope
    - **hooks**: Custom React hooks
    - **pages**: Application pages/routes
    - **services**: API services
    - **styles**: Theme/global styles
    - **types**: Common Type declarations
    - **utils**: Utility functions
    - **App.tsx**: Main application component
    - **main.tsx**: Entry point
    - **vite-env.d.ts**: Vite type definitions
  - **.eslintrc.cjs**: ESLint configuration
  - **.gitignore**: Git ignore configuration
  - **index.html**: HTML template
  - **nginx.conf**: Nginx configuration for production
  - **package.json**: Project dependencies and scripts
  - **tsconfig.json**: TypeScript configuration
  - **vite.config.ts**: Vite configuration
  - **Dockerfile**: Production Docker configuration
  - **README.md**: Project documentation

## Dependencies
 Main Dependencies

| Dependency               | Description                          |
|--------------------------|--------------------------------------|
| **React**                | UI library                           |
| **React Router DOM**     | Routing solution                     |
| **TypeScript**           | Type safety                          |
| **Ant Design**           | UI component library                |
| **Tanstack Query**       | Data fetching library               |
| **XYFlow/ReactFlow**     | Flow diagram components             |
| **React Markdown**       | Markdown renderer                    |
| **Styled Components**    | CSS-in-JS styling solution           |
| **Axios**                | HTTP client                          |


Dev Dependencies

| Dependency               | Description                                      |
|--------------------------|--------------------------------------------------|
| **Vite**                 | Build tool and development server               |
| **ESLint**               | Code linting                                    |
| **TypeScript ESLint**    | TypeScript integration for ESLint               |
| **Prettier**             | Code formatting                                 |
