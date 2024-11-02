import pygame
from pygame.locals import *
from OpenGL.GL import *
from OpenGL.GLU import *
from OpenGL.GLUT import *
import requests

# Constants
SCREEN_WIDTH = 900
SCREEN_HEIGHT = 600
X_MIN, X_MAX, Y_MIN, Y_MAX, DIM_BOARD = 0, 825, 0, 825, 825
ROBOT_SCALE = 20
BOX_SCALE = 10
URL_BASE = "http://localhost:8000"

# Custom Imports
from OpMat import OpMat
from Robot import Robot
from Box import Box

# Initialize Pygame and OpenGL
pygame.init()
opera = OpMat()

# Initialize data and objects
robots = {}
packages = {}
storages = {}

# Helper Functions
def fetch_data():
    """Fetch data from server and handle errors."""
    try:
        response = requests.post(URL_BASE + "/simulations", allow_redirects=False)
        response.raise_for_status()
        datos = response.json()
        robots_data = datos["robots"]
        boxes_data = datos["boxes"]
        storages_data = datos["storages"]
        location = datos["Location"]
        return robots_data, boxes_data, storages_data, location
    except requests.exceptions.RequestException as e:
        print(f"Error fetching data: {e}")
        return None, None, None, None

def update_data(location):
    """Update data from server using the specified location."""
    try:
        response = requests.get(URL_BASE + location)
        response.raise_for_status()
        return response.json()
    except requests.exceptions.RequestException as e:
        print(f"Error updating data: {e}")
        return None

def initialize_objects(robots_data, boxes_data, storages_data):
    """Initialize robot, box, and storage objects based on the server data."""
    for i, _ in enumerate(robots_data):
        robots[f"r{i}"] = Robot(opera)
    for i, _ in enumerate(boxes_data):
        packages[f"b{i}"] = Box(opera)
    for i, _ in enumerate(storages_data):
        storages[f"s{i}"] = Box(opera)

def get_scaled_coords(data, scale_factor=10):
    """Get scaled coordinates from data for a given scale factor."""
    return [(item["pos"][0] * scale_factor, item["pos"][1] * scale_factor) for item in data]

def Axis():
    """Render the X and Y axes."""
    glShadeModel(GL_FLAT)
    glLineWidth(3.0)
    glColor3f(1.0, 0.0, 0.0)
    glBegin(GL_LINES)
    glVertex2f(X_MIN, 0.0)
    glVertex2f(X_MAX, 0.0)
    glEnd()
    glColor3f(0.0, 1.0, 0.0)
    glBegin(GL_LINES)
    glVertex2f(0.0, Y_MIN)
    glVertex2f(0.0, Y_MAX)
    glEnd()
    glLineWidth(1.0)

def display(robots_data, boxes_data, storages_data):
    """Render the entire scene with robots, boxes, and storages."""
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT)
    glColor3f(0.3, 0.3, 0.3)
    glBegin(GL_QUADS)
    glVertex3d(0, 0, -DIM_BOARD)
    glVertex3d(0, 0, DIM_BOARD)
    glVertex3d(0, 0, DIM_BOARD)
    glVertex3d(0, 0, -DIM_BOARD)
    glEnd()

    for i, car in enumerate(robots_data):
        robot = robots[f"r{i}"]
        robot.setColor(1.0, 1.0, 1.0)
        robot.setScale(0.5)
        glPushMatrix()
        robot.opera.translate(car["pos"][0] * ROBOT_SCALE, car["pos"][1] * ROBOT_SCALE)
        robot.render()
        glPopMatrix()

    for i, box in enumerate(boxes_data):
        package = packages[f"b{i}"]
        package.setColor(1.0, 1.0, 0.0)
        glPushMatrix()
        package.opera.translate(box["pos"][0] * BOX_SCALE, box["pos"][1] * BOX_SCALE)
        package.render()
        glPopMatrix()

    for i, storage in enumerate(storages_data):
        storage_obj = storages[f"s{i}"]
        storage_obj.setColor(0.0, 1.0, 1.0)
        glPushMatrix()
        storage_obj.opera.translate(storage["pos"][0] * BOX_SCALE, storage["pos"][1] * BOX_SCALE)
        storage_obj.render()
        glPopMatrix()

    pygame.display.flip()

def handle_input():
    """Handle keyboard input."""
    keys = pygame.key.get_pressed()
    if keys[pygame.K_UP]:
        pass
    if keys[pygame.K_DOWN]:
        pass
    if keys[pygame.K_LEFT]:
        pass
    if keys[pygame.K_RIGHT]:
        pass

def init_opengl():
    """Initialize OpenGL settings."""
    screen = pygame.display.set_mode((SCREEN_WIDTH, SCREEN_HEIGHT), DOUBLEBUF | OPENGL)
    pygame.display.set_caption("OpenGL: Amazon Robots")
    glMatrixMode(GL_PROJECTION)
    glLoadIdentity()
    gluOrtho2D(-25, DIM_BOARD, -25, DIM_BOARD)
    glMatrixMode(GL_MODELVIEW)
    glLoadIdentity()
    glClearColor(0, 0, 0, 0)
    glPolygonMode(GL_FRONT_AND_BACK, GL_LINE)
    glShadeModel(GL_FLAT)
    opera.loadId()

# Main Execution
robots_data, boxes_data, storages_data, location = fetch_data()
if robots_data:
    initialize_objects(robots_data, boxes_data, storages_data)
    init_opengl()

    # Set your desired update interval and frame delay here
    UPDATE_INTERVAL = 1  # Update data every 500 milliseconds
    FRAME_DELAY = 1       # Frame delay set to 30 milliseconds

    done = False
    while not done:
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                done = True

        handle_input()
        Axis()
        display(robots_data, boxes_data, storages_data)

        # Update data every UPDATE_INTERVAL milliseconds
        if pygame.time.get_ticks() % UPDATE_INTERVAL == 0:
            new_data = update_data(location)
            if new_data:
                robots_data = new_data["robots"]
                boxes_data = new_data["boxes"]
                storages_data = new_data["storages"]

        # Reduce delay to FRAME_DELAY for a faster frame rate
        pygame.time.wait(FRAME_DELAY)

    pygame.quit()
else:
    print("Failed to fetch initial data.")