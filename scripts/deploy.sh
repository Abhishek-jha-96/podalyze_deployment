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
    docker-compose build --no-cache
}

# Function to deploy services
deploy_services() {
    echo "🎯 Deploying services..."
    
    case $1 in
        "dev")
            docker-compose -f docker-compose.yml -f docker-compose.dev.yml up -d
            ;;
        "prod")
            docker-compose -f docker-compose.yml -f docker-compose.prod.yml up -d
            ;;
        *)
            docker-compose up -d
            ;;
    esac
}

# Function to run health checks
health_checks() {
    echo "🏥 Running health checks..."
    
    # Wait for services to be ready
    sleep 30
    
    # Check frontend
    if curl -f http://localhost/health > /dev/null 2>&1; then
        echo "✅ Frontend is healthy"
    else
        echo "❌ Frontend health check failed"
    fi
    
    # Check backend
    if curl -f http://localhost/api/health > /dev/null 2>&1; then
        echo "✅ Backend is healthy"
    else
        echo "❌ Backend health check failed"
    fi
    
    # Check inference server
    if curl -f http://localhost:8000/health > /dev/null 2>&1; then
        echo "✅ Inference server is healthy"
    else
        echo "❌ Inference server health check failed"
    fi
}

# Function to show logs
show_logs() {
    echo "📋 Showing recent logs..."
    docker-compose logs --tail=50
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
            health_checks
            ;;
        "logs")
            show_logs
            ;;
        "cleanup")
            echo "🧹 Cleaning up..."
            docker-compose down
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