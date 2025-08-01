# Plausible Analytics Setup Instructions

## 🚀 Quick Start

This setup will deploy Plausible Analytics on your VPS using Docker.

### Prerequisites
- Docker and Docker Compose (will be installed automatically)
- Port 8000 available on your VPS
- Domain name (optional, for production use)

### Installation Steps

1. **Set up production environment:**
   ```bash
   ./setup-production-env.sh
   ```

2. **Start Plausible Analytics:**
   ```bash
   ./manage.sh start
   ```

3. **Wait for services to start** (about 30-60 seconds)

4. **Access your analytics dashboard:**
   - URL: http://your-server-ip:8000 (or your domain)
   - Create your first account
   - Add your first website

## 📊 What is Plausible Analytics?

Plausible Analytics is a privacy-focused alternative to Google Analytics that:
- ✅ Respects user privacy (GDPR/CCPA compliant)
- ✅ No cookies or personal data collection
- ✅ Lightweight tracking script
- ✅ Simple, clean dashboard
- ✅ Self-hosted (you own your data)

## 🔧 Configuration Options

### Environment Variables

You can customize the setup by editing the `.env` file:

```bash
# Required settings
BASE_URL=https://your-domain.com
SECRET_KEY_BASE=your-generated-secret-key
TOTP_VAULT_KEY=your-generated-totp-key

# User management
ADMIN_USER_IDS=1
DISABLE_REGISTRATION=false

# Email configuration (optional)
MAILER_ADAPTER=Bamboo.SMTPAdapter
SMTP_HOST_ADDR=smtp.gmail.com
SMTP_USER_NAME=your-email@gmail.com
SMTP_USER_PWD=your-app-password
```

### Security Recommendations

1. **Use HTTPS**: Set up SSL/TLS with a reverse proxy (nginx)
2. **Change default passwords**: Update database passwords
3. **Restrict access**: Use firewall rules
4. **Regular backups**: Backup PostgreSQL and ClickHouse data

## 🛠️ Management Commands

```bash
# View logs
docker-compose logs -f

# Stop services
docker-compose down

# Restart services
docker-compose restart

# Update to latest version
docker-compose pull
docker-compose up -d

# Backup data
docker-compose exec postgres pg_dump -U plausible plausible > backup.sql
```

## 📁 Data Storage

Your data is stored in Docker volumes:
- `postgres-data`: PostgreSQL database
- `clickhouse-data`: ClickHouse analytics data
- `plausible-data`: Plausible application data

## 🔗 Integration

### Adding to Your Website

Add this script to your website's `<head>` section:

```html
<script defer data-domain="your-domain.com" src="http://your-server-ip:8000/js/script.js"></script>
```

### API Access

Plausible provides APIs for:
- Stats API: `http://your-server-ip:8000/api/stats`
- Events API: `http://your-server-ip:8000/api/event`

## 🌐 Domain Setup (Optional)

If you want to use a custom domain (e.g., `analytics.yourdomain.com`):

### 1. DNS Configuration
Add an A record pointing to your server IP:
- **Type**: `A`
- **Name**: `analytics` (or your preferred subdomain)
- **Value**: Your server IP address

### 2. Nginx Configuration
Create an Nginx configuration file for your domain:
```bash
sudo nano /etc/nginx/sites-available/analytics.yourdomain.com
```

### 3. SSL Certificate
Obtain SSL certificate using Certbot:
```bash
sudo certbot --nginx -d analytics.yourdomain.com
```

### 4. Update Plausible Configuration
Update the `BASE_URL` in `docker-compose.yml`:
```yaml
environment:
  - BASE_URL=https://analytics.yourdomain.com
```

## 🆘 Troubleshooting

### Common Issues

1. **Port 8000 already in use:**
   ```bash
   sudo netstat -tulpn | grep :8000
   # Change port in docker-compose.yml
   ```

2. **Services not starting:**
   ```bash
   docker-compose logs
   # Check for configuration errors
   ```

3. **Database connection issues:**
   ```bash
   docker-compose restart postgres clickhouse
   ```

### Getting Help

- [Plausible Documentation](https://plausible.io/docs)
- [Community Forum](https://github.com/plausible/analytics/discussions)
- [GitHub Issues](https://github.com/plausible/analytics/issues)

## 🔄 Updates

To update Plausible Analytics:

```bash
cd /home/tuanbt/analytics
git pull origin main
docker-compose pull
docker-compose up -d
```

## 📈 Scaling

For production use, consider:
- Using a reverse proxy (nginx/traefik)
- Setting up SSL certificates
- Configuring automated backups
- Monitoring with tools like Prometheus
- Load balancing for high traffic 