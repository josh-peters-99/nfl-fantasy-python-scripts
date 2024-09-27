# NFL Fantasy Player Data Scraper

## Overview

This project is a Python script that scrapes player data from the NFL Fantasy website. It retrieves player statistics for a specified season and stores the data in a MongoDB Atlas database. The script leverages the `requests` library for HTTP requests and `BeautifulSoup` for HTML parsing, along with `pymongo` for database interactions.

## Features

- Fetches the total count of NFL Fantasy players available for a specified season.
- Retrieves detailed player statistics including player name, position, team, and various performance metrics.
- Stores player data in a MongoDB Atlas collection with upsert functionality to avoid duplicate entries.

## Technologies Used

- Python
- Requests
- BeautifulSoup
- PyMongo
- MongoDB Atlas

## Requirements

To run this project, you will need:

- Python 3.x
- `requests`, `beautifulsoup4`, and `pymongo` packages. You can install these using pip:

```bash
pip install requests beautifulsoup4 pymongo
