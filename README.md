# Podalyze

Podalyze is a web application that provides analytics over podcasts — predicting expected average watch time, and classifying genre and sentiment — to help creators and platforms understand audience engagement before or after publishing.

## Features

- **Podcast Analytics Dashboard** — Clean, animated UI surfacing engagement metrics and prediction results at a glance.
- **Average Watch Time Prediction** — Custom regression models (XGBoost + CatBoost) trained on engagement-driving features such as episode length, host popularity, and genre.
- **Genre & Sentiment Classification** — Zero-shot LLM inference (Hugging Face) to classify podcast genre and sentiment without task-specific fine-tuning.
- **Async, Distributed Inference** — Analysis requests are validated and queued as background jobs so the UI stays responsive regardless of inference time.

## Architecture

Podalyze is split into three cooperating services:

```
┌─────────────┐      ┌──────────────────┐      ┌───────────────────────┐
│   React UI  │─────▶│  NestJS Backend  │─────▶│  FastAPI Inference API │
│ (dashboard, │      │ (auth, CRUD,     │      │ (request validation,   │
│  animations)│◀─────│  podcast data)   │◀─────│  triggers Celery task)│
└─────────────┘      └──────────────────┘      └───────────┬───────────┘
                              │                             │
                              ▼                             ▼
                        ┌──────────┐               ┌─────────────────┐
                        │ MongoDB  │               │  Celery Worker   │
                        │(Mongoose)│               │  (async task)    │
                        └──────────┘               └────────┬─────────┘
                                                              │
                                        ┌─────────────────────┼─────────────────────┐
                                        ▼                     ▼                     ▼
                                 ┌─────────────┐      ┌───────────────┐     ┌───────────────┐
                                 │ YouTube API │      │ NLP Inference │     │ Custom Model   │
                                 │ (metadata)  │      │ (genre/       │     │ (XGBoost +     │
                                 │             │      │  sentiment,   │     │  CatBoost:     │
                                 │             │      │  HF zero-shot)│     │  watch time)   │
                                 └─────────────┘      └───────────────┘     └───────────────┘
```

**Flow:**
1. The React frontend handles all dashboard visualization, metrics display, and UX (routing via React Router, animations via Motion).
2. The **NestJS** backend exposes CRUD APIs for auth, login, and podcast analysis requests, and reads/writes results via **Mongoose**/**MongoDB**.
3. When an analysis is triggered, NestJS calls a dedicated **FastAPI** microservice over HTTP. FastAPI performs initial request validation, then dispatches an async **Celery** task (backed by **Redis**) so inference doesn't block the request.
4. The Celery task fetches relevant podcast metadata via the **YouTube API**, then runs:
   - **NLP inference** — genre and sentiment classification via zero-shot LLM inference (Hugging Face).
   - **Custom model inference** — average watch time prediction via XGBoost + CatBoost, using features like total length, host popularity, and genre.
5. Results are persisted back to MongoDB and surfaced on the dashboard.

## Tech Stack

**Frontend:** React, Tailwind CSS, Redux Toolkit, ShadCN UI, React Router, Motion

**Backend:** NestJS, Mongoose, FastAPI, Celery, Redis

**Inference / ML:** XGBoost, CatBoost (average watch time prediction), Hugging Face zero-shot models (genre & sentiment analysis)

**Infra:** Docker (orchestration & deployment), MongoDB, Bash scripts

## Getting Started

> Fill in the specifics for your setup (ports, env vars, service names) — this is a generic scaffold based on the architecture above.

### Prerequisites
- Docker & Docker Compose
- Node.js (for local frontend/NestJS dev outside containers, if needed)
- Python 3.x (for local FastAPI/Celery dev outside containers, if needed)

### Run with Docker

```bash
git clone <repo-url>
cd podalyze
docker compose up --build
```

### Environment Variables

Create a `.env` file for each service (frontend, NestJS backend, FastAPI inference service) with values such as:

```
MONGO_URI=
REDIS_URL=
YOUTUBE_API_KEY=
HUGGINGFACE_API_TOKEN=
JWT_SECRET=
```

## Project Structure

```
podalyze_deployment/
├── services/
    ├── podalyze                  # React app (dashboard, auth UI)
    ├── podalyze_backend/         # NestJS service (auth, CRUD, orchestration)
    ├── podalyze_inference/       # FastAPI service (validation, Celery task dispatch)
    ├── scripts/                  # Bash automation scripts
    └── docker-compose.yml
```
