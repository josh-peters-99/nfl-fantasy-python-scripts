import requests
from bs4 import BeautifulSoup
from typing import List
from datetime import datetime
from pymongo import MongoClient

def get_player_count(season: int) -> int:
    """
    Fetches the total count of players listed on the NFL Fantasy player research page.

    This function sends an HTTP GET request to the NFL Fantasy player research page,
    parses the response to extract the player count from the pagination title,
    and returns the count as an integer.

    Returns:
        int: The total number of players available on the NFL Fantasy player research page.

    Raises:
        ValueError: If the player count cannot be extracted from the page.
    """
    url = f'https://fantasy.nfl.com/research/players?position=O&sort=pts&statCategory=stats&statSeason={season}'
    response = requests.get(url)

    if response.status_code == 200:
        soup = BeautifulSoup(response.content, 'html.parser')

        # Extract pagination title that contains the player count
        pagination_title = soup.find('span', {'class': 'paginationTitle'})

        # Split the text and get the last word, which should be the player count
        player_count = pagination_title.text.split()[-1]

        # Convert the player count to an integer and return
        return int(player_count)
    else:
        raise ValueError(f"Failed to retrieve player count, status code: {response.status_code}")

def get_player_data(season: int, player_count: int) -> List[List[str]]:
    """
    Retrieves player data from the NFL fantasy website for a given season.

    Args:
        season (int): The season year to retrieve data for.
        player_count (int): The total number of players to retrieve data for.

    Returns:
        List[List[str]]: A list of lists containing player data, where each inner list represents
                         a player's details in the following order:
                         [player_name, position, team, ...other details...]
    """
    all_player_data = []

    # Calculate the range for pagination
    start_count = 1
    end_count = (player_count // 25) * 25 + 1

    for page in range(start_count, end_count, 25):
        # Construct the URL for the current page
        url = f'https://fantasy.nfl.com/research/players?position=O&sort=pts&statCategory=stats&statSeason={season}&offset={page}'
        response = requests.get(url)

        if response.status_code == 200:
            # Parse the HTML content
            soup = BeautifulSoup(response.content, 'html.parser')
            table = soup.find('tbody')

            if table:
                rows = table.find_all('tr')

                for row in rows:
                    cells = row.find_all('td')
                    cell_data = []
                    for i in range(len(cells)):
                        if i == 0:
                            # Extract player name, position, and team from the first cell
                            split_arr = cells[i].text.split(' ')
                            player_name = f'{split_arr[0]} {split_arr[1]}'
                            position = split_arr[2]

                            try:
                                team = split_arr[4]
                            except IndexError:
                                team = None

                            cell_data.append(player_name)
                            cell_data.append(position)
                            cell_data.append(team)
                        else:
                            # Extract remaining details
                            cell_data.append(cells[i].get_text(strip=True))
                    all_player_data.append(cell_data)

    return all_player_data

def insert_player_data(player_data: List[List[str]], db_name: str, collection_name: str) -> None:
    """
    Inserts player data into a MongoDB Atlas collection.

    Args:
        player_data (List[List[str]]): The list of lists containing player data.
        db_name (str): The name of the MongoDB database.
        collection_name (str): The name of the MongoDB collection.
    """
    # MongoDB Atlas connection string
    connection_string = 'mongodb+srv://jgp21199:Vgthw4vDykbLz42r@nflclusterone.mxg0u.mongodb.net/?retryWrites=true&w=majority&appName=NFLClusterOne'

    # Create a MongoClient object
    client = MongoClient(connection_string)

    # Access the specified database
    db = client[db_name]

    # Access the specified collection
    collection = db[collection_name]

    # Prepare the data for insertion
    documents = []
    for data in player_data:
        document = {
            'player_name': data[0],
            'position': data[1],
            'team': data[2],
            'opponent': data[3],
            'passing_yds': data[4],
            'passing_td': data[5],
            'passing_int': data[6],
            'rushing_yds': data[7],
            'rushing_td': data[8],
            'receiving_rec': data[9],
            'receiving_yds': data[10],
            'receiving_td': data[11],
            'ret_td': data[12],
            'fum_td': data[13],
            '2pt': data[14],
            'fum_lost': data[15],
            'points': data[16]
        }
        documents.append(document)

    # Insert data into the collection
    collection.insert_many(documents)

    # Close the client connection
    client.close()

def main():
    """
    Main function to execute the primary functionality of the script.
    It retrieves player data for the current year with the given player count.
    """
    current_year = datetime.now().year

    player_data = get_player_data(current_year, get_player_count(current_year))

    insert_player_data(player_data, 'nfl_fantasy', 'players')

if __name__ == '__main__':
    main()
