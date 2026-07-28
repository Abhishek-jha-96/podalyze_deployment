#!/bin/bash
# scripts/deploy.sh - Main deployment script

set -e

echo "🚀 Starting Podalyze Deployment..."

# Load environment variables
if [ -f .env ]; then
    export $(cat .env | grep -v '^#' | xargs)
else
    echo "❌ .env file not found. Please copy .env.example to .env and configure it."
    exit 1
fi

# Function to update git submodules
update_submodules() {
    echo "📦 Updating git submodules..."
    git submodule update --init --recursive
    
    # Optionally checkout specific branches/tags
    if [ ! -z "$FRONTEND_VERSION" ]; then
        cd services/frontend && git checkout $FRONTEND_VERSION && cd ../..
    fi
    
    if [ ! -z "$BACKEND_VERSION" ]; then
        cd services/backend && git checkout $BACKEND_VERSION && cd ../..
    fi
    
    if [ ! -z "$INFERENCE_VERSION" ]; then
        cd services/inference-server && git checkout $INFERENCE_VERSION && cd ../..
    fi
}

# Function to build images
build_images() {
    echo "🔨 Building Docker images..."
    docker compose -f docker-compose.yml --env-file .envs/.env.production build --no-cache
}

# Function to deploy services
deploy_services() {
    echo "🎯 Deploying services..."
    
    case $1 in
        "dev")
            ./scripts/run_server.sh dev
            ;;
        "prod")
            ./scripts/run_server.sh up
            ;;
        *)
            ./scripts/run_server.sh up
            ;;
    esac
}

# Function to show logs
show_logs() {
    echo "📋 Showing recent logs..."
    docker compose -f docker-compose.yml --env-file .envs/.env.production logs --tail=50
}

# Main deployment flow
main() {
    case $1 in
        "update")
            update_submodules
            ;;
        "build")
            build_images
            ;;
        "deploy")
            update_submodules
            build_images
            deploy_services $2
            ;;
        "logs")
            show_logs
            ;;
        "cleanup")
            echo "🧹 Cleaning up..."
            ./scripts/run_server.sh down
            docker system prune -f
            ;;
        *)
            echo "Usage: $0 {update|build|deploy [dev|prod]|logs|cleanup}"
            echo ""
            echo "Commands:"
            echo "  update     - Update git submodules"
            echo "  build      - Build Docker images"
            echo "  deploy     - Full deployment (update + build + deploy)"
            echo "  logs       - Show recent logs"
            echo "  cleanup    - Stop services and cleanup"
            exit 1
            ;;
    esac
}

main "$@"