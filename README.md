# Podalyze

Podalyze is a web application that provides analytics over podcasts — predicting expected average watch time, and classifying genre and sentiment — to help creators and platforms understand audience engagement before or after publishing.

## Features

- **Podcast Analytics Dashboard** — React dashboard for managing podcasts, searching episodes, and reviewing predicted watch time, genre, and sentiment at a glance.
- **Average Watch Time Prediction** — Custom regression models (XGBoost + CatBoost) trained on engagement-driving features such as episode length, host/guest popularity, number of ads, and genre.
- **Genre & Sentiment Classification** — Hugging Face inference: RoBERTa sentiment classification (`cardiffnlp/twitter-roberta-base-sentiment`) and BART zero-shot genre labeling (`facebook/bart-large-mnli`).
- **Async, Distributed Inference** — Analysis requests are validated by FastAPI and queued as Celery background jobs (Redis broker) so the UI stays responsive regardless of inference time.

## Architecture

Podalyze is split into three cooperating services (plus shared infra):

```
┌─────────────┐      ┌──────────────────┐      ┌───────────────────────┐
│   React UI  │────▶│  NestJS Backend  │────▶│ FastAPI Inference API │
│ (dashboard, │      │ (auth, CRUD,     │      │ (request validation,  │
│  analytics) │◀────│  podcast data)   │◀────│ triggers Celery task) │
└─────────────┘      └──────────────────┘      └───────────┬───────────┘
                              │                            │
                              ▼                            ▼
                        ┌──────────┐               ┌─────────────────┐
                        │ MongoDB  │               │  Celery Worker  │
                        │(Mongoose)│               │  (async task)   │
                        └──────────┘               └────────┬────────┘
                                                            │
                                      ┌─────────────────────┼─────────────────────┐
                                      ▼                     ▼                     ▼
                                 ┌─────────────┐      ┌───────────────┐     ┌───────────────┐
                                 │ YouTube API │      │ NLP Inference │     │ Custom Model  │
                                 │ (metadata + │      │ (genre/       │     │ (XGBoost +    │
                                 │  transcript)│      │  sentiment,   │     │  CatBoost:    │
                                 │             │      │  HF Inference)│     │  watch time)  │
                                 └─────────────┘      └───────────────┘     └───────────────┘
```

**Flow:**
1. The React frontend (React Router + Vite) handles dashboard visualization, auth UI, podcast CRUD forms, and UX animations (Motion).
2. The **NestJS** backend exposes JWT auth and CRUD APIs for users, projects (podcasts), and analysis tasks, and reads/writes via **Mongoose**/**MongoDB**.
3. When an analysis is triggered, NestJS calls the **FastAPI** inference service (`POST /api/v1/analyze`). FastAPI validates the payload, then dispatches an async **Celery** task (broker: **Redis**) so inference does not block the HTTP request.
4. The Celery task fetches podcast metadata and transcripts via the **YouTube Data API** / transcript helpers, then runs:
   - **NLP inference** — sentiment (RoBERTa) and genre (BART zero-shot) via Hugging Face Inference.
   - **Custom model inference** — average watch time prediction via XGBoost + CatBoost, using features like total length, host/guest popularity, ads, and genre.
5. Results are persisted back to MongoDB (task/project updates) and surfaced on the analytics dashboard.

## 🎥 Demo

<div>
   <a href="https://www.loom.com/share/5843eae483b347cd8c9a1f23ef617704">
      <p>Podalyze Demo, Podcast Analysis Pipeline Overview - Watch Video</p>
   </a>
   <a href="https://www.loom.com/share/5843eae483b347cd8c9a1f23ef617704">
   <img style="max-width:300px;" src="https://cdn.loom.com/sessions/thumbnails/5843eae483b347cd8c9a1f23ef617704-8376b9aff554790e-full-play.gif#t=0.1">
   </a>
</div>

## Tech Stack

**Frontend:** React 19, Vite, React Router 7, Tailwind CSS 4, Redux Toolkit, ShadCN/Radix UI, React Hook Form, Motion, pnpm

**Backend:** NestJS, Passport JWT, Mongoose, Swagger, FastAPI, Celery, Redis, Uvicorn

**Inference / ML:** XGBoost, CatBoost, scikit-learn, Hugging Face Hub (`twitter-roberta-base-sentiment`, `bart-large-mnli`), YouTube Data API, youtube-transcript-api

**Infra:** Docker Compose, MongoDB 8, Redis 7, mongo-express, Nginx (optional reverse proxy), Bash scripts

## Getting Started

### Prerequisites
- Docker & Docker Compose
- Git (with submodule support)
- Node.js + pnpm (for local frontend/NestJS development outside containers, if needed)
- Python 3.x (for local FastAPI/Celery development outside containers, if needed)

### Run with Docker

```bash
git clone --recurse-submodules https://github.com/Abhishek-jha-96/podalyze_deployment.git
cd podalyze_deployment

# Configure environment (shared by all compose services)
cp .env.example .envs/.env.development
# Edit .envs/.env.development — replace change-me / placeholder secrets

docker compose --env-file .envs/.env.development up --build
```

Alternatively, use the helper script (expects `.envs/.env.production` by default):

```bash
cp .env.example .envs/.env.production
./scripts/run_server.sh up          # or: ./scripts/run_server.sh dev
```

**Default ports (development compose):**

| Service          | Port  |
|------------------|-------|
| Frontend         | 5173  |
| NestJS backend   | 3000  |
| Inference API    | 8000  |
| Redis            | 6379  |
| MongoDB          | 27017 |
| mongo-express    | 8081  |

### Environment Variables

Copy `.env.example` to `.envs/.env.development` (local compose) or `.envs/.env.production` (script/deploy). Key variables:

```
# Frontend
VITE_BASE_API_URL=http://localhost:3000

# NestJS backend
ALLOWED_ORIGINS=http://localhost:5173
INFERENCE_BASE_URL=http://inference-server:8000
SECRET_KEY=
AUTH_JWT_SECRET=
AUTH_REFRESH_SECRET=

# MongoDB
MONGO_INITDB_ROOT_USERNAME=podalyze
MONGO_INITDB_ROOT_PASSWORD=
DATABASE_HOST=mongo
DATABASE_PORT=27017
DATABASE_USERNAME=podalyze
DATABASE_PASSWORD=
DATABASE_NAME=podalyze

# Inference / Celery
CELERY_BROKER_URL=redis://redis:6379/0
PROJECT_NAME=Podalyze Inference
DEVELOPER_KEY=          # YouTube Data API v3 key
OAUTH_CRED=
HF_TOKEN=               # Hugging Face API token
FRONTEND_HOST=http://localhost:5173
BACKEND_CORS_ORIGINS=http://localhost:5173
```

See `.env.example` for the full list (JWT expiry times, mongo-express credentials, optional submodule version pins, etc.).

## Project Structure

```
podalyze_deployment/
├── services/
│   ├── podalyze/                 # React frontend (git submodule)
│   ├── podalyze_backend/         # NestJS API — auth, projects, tasks (git submodule)
│   └── podalyze_inference/       # FastAPI + Celery worker — ML inference (git submodule)
├── scripts/                      # run_server.sh, deploy.sh
├── nginx/                        # Optional reverse-proxy config
├── docker-compose.yml            # Local / development stack
├── docker-compose.prod.yml       # Production-oriented compose overlay
├── .env.example                  # Env template for .envs/
└── .envs/                        # .env.development / .env.production (not committed)
```
