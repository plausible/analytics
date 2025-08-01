#!/bin/bash

# Plausible Analytics Management Script

case "$1" in
    start)
        echo "🚀 Starting Plausible Analytics..."
        docker-compose up -d
        echo "✅ Plausible Analytics is starting..."
        echo "📊 Access at: http://your-server-ip:8000"
        ;;
    stop)
        echo "🛑 Stopping Plausible Analytics..."
        docker-compose down
        echo "✅ Plausible Analytics stopped"
        ;;
    restart)
        echo "🔄 Restarting Plausible Analytics..."
        docker-compose restart
        echo "✅ Plausible Analytics restarted"
        ;;
    status)
        echo "📊 Plausible Analytics Status:"
        docker-compose ps
        ;;
    logs)
        echo "📋 Showing logs..."
        docker-compose logs -f
        ;;
    update)
        echo "🔄 Updating Plausible Analytics..."
        docker-compose pull
        docker-compose up -d
        echo "✅ Plausible Analytics updated"
        ;;
    backup)
        echo "💾 Creating backup..."
        docker-compose exec postgres pg_dump -U plausible plausible > backup_$(date +%Y%m%d_%H%M%S).sql
        echo "✅ Backup created"
        ;;
    migrate)
        echo "🗄️ Running database migrations..."
        docker-compose exec plausible /app/bin/plausible eval "Plausible.Release.migrate"
        echo "✅ Migrations completed"
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status|logs|update|backup|migrate}"
        echo ""
        echo "Commands:"
        echo "  start   - Start Plausible Analytics"
        echo "  stop    - Stop Plausible Analytics"
        echo "  restart - Restart Plausible Analytics"
        echo "  status  - Show service status"
        echo "  logs    - Show application logs"
        echo "  update  - Update to latest version"
        echo "  backup  - Create database backup"
        echo "  migrate - Run database migrations"
        exit 1
        ;;
esac 