#!/usr/bin/env python3
"""
Script to initialize WhatsApp database tables
Run this once to create the necessary tables in YDB
"""

import sys
import os
import logging

# Add the shared directory to the path
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from database_utils import initialize_whatsapp_database

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)

def main():
    """Initialize WhatsApp database tables"""
    try:
        print("Initializing WhatsApp database tables...")
        initialize_whatsapp_database()
        print("✅ WhatsApp database initialization completed successfully!")
        
    except Exception as e:
        print(f"❌ Database initialization failed: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()