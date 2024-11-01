import pygame
from pygame.locals import *

# Cargamos las bibliotecas de OpenGL
from OpenGL.GL import *
from OpenGL.GLU import *
from OpenGL.GLUT import *

screen_width = 900
screen_height = 600

# Variables para dibujar los ejes del sistema
X_MIN = 0
X_MAX = 100
Y_MIN = 0
Y_MAX = 100
# Dimension del Plano
DimBoard = 100

# Archivos propios
from OpMat import OpMat
from Robot import Robot
from Box import Box

import requests

# Define `datos` as a global variable
global datos
URL_BASE = "http://localhost:8000"
r = requests.post(URL_BASE + "/simulations", allow_redirects=False)
datos = r.json()
LOCATION = datos["Location"]

initialX = datos["cars"][0]["pos"][0]
initialY = datos["cars"][0]["pos"][1]

carsXCoords = []
carsYCoords = []
for car in datos["cars"]:
    carsXCoords.append(car["pos"][0])
    carsYCoords.append(car["pos"][1])

boxesXCoords = []
boxesYCoords = []
for box in datos["boxes"]:
    boxesXCoords.append(box["pos"][0])
    boxesYCoords.append(box["pos"][1])

pygame.init()

opera = OpMat()

robots = {f"r{i}": Robot(opera) for i, _ in enumerate(datos["cars"])}
packages = {f"b{i}": Box(opera) for i, _ in enumerate(datos["boxes"])}
storages = {f"s{i}": Box(opera) for i, _ in enumerate(datos["storages"])}

def Axis():
    glShadeModel(GL_FLAT)
    glLineWidth(3.0)
    # X axis in red
    glColor3f(1.0, 0.0, 0.0)
    glBegin(GL_LINES)
    glVertex2f(X_MIN, 0.0)
    glVertex2f(X_MAX, 0.0)
    glEnd()
    # Y axis in green
    glColor3f(0.0, 1.0, 0.0)
    glBegin(GL_LINES)
    glVertex2f(0.0, Y_MIN)
    glVertex2f(0.0, Y_MAX)
    glEnd()
    glLineWidth(1.0)


def display():
    global datos
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT)
    glColor3f(0.3, 0.3, 0.3)
    glBegin(GL_QUADS)
    glVertex3d(0, 0, -DimBoard)
    glVertex3d(0, 0, DimBoard)
    glVertex3d(0, 0, DimBoard)
    glVertex3d(0, 0, -DimBoard)
    glEnd()
    
    for i, car in enumerate(datos["cars"]):
        robot = robots[f"r{i}"]
        robot.setColor(1.0, 1.0, 1.0)
        robot.setScale(1)
        robot.render()

        response = requests.get(URL_BASE + LOCATION)
        datos = response.json()
        car_data = datos["cars"][i]
        robot.opera.translate(car_data["pos"][0], car_data["pos"][1])
    
    for i, box in enumerate(datos["boxes"]):
        package = packages[f"b{i}"]
        package.setColor(1.0, 1.0, 0.0)
        package.setScale(1)
        package.render()

        box_data = box  # Fetch box position from the updated `datos`
        package.opera.translate(box_data["pos"][0], box_data["pos"][1])
    
    for i, storage in enumerate(datos["storages"]):
        storage = storages[f"s{i}"]
        storage.setColor(0.0,1.0,1.0)
        storage.setScale(1)
        storage.render()

opera.loadId()


def init():
    screen = pygame.display.set_mode((screen_width, screen_height), DOUBLEBUF | OPENGL)
    pygame.display.set_caption("OpenGL: Amazon Robots")

    glMatrixMode(GL_PROJECTION)
    glLoadIdentity()
    gluOrtho2D(0, 100, 0, 100)
    glMatrixMode(GL_MODELVIEW)
    glLoadIdentity()
    glClearColor(0, 0, 0, 0)
    # OPCIONES: GL_LINE, GL_POINT, GL_FILL
    glPolygonMode(GL_FRONT_AND_BACK, GL_LINE)
    glShadeModel(GL_FLAT)


# código principal ---------------------------------
init()

done = False
while not done:
    keys = pygame.key.get_pressed()
    for event in pygame.event.get():
        if event.type == pygame.QUIT:
            done = True
        if keys[pygame.K_UP]:
            pass
            # r1.moveUp()
        if keys[pygame.K_DOWN]:
            pass
            # r1.moveDown()
        if keys[pygame.K_LEFT]:
            pass
            # r1.turnLeft()
        if keys[pygame.K_RIGHT]:
            pass
            # r1.turnRight()
    glClear(GL_COLOR_BUFFER_BIT)
    Axis()
    display()  
    pygame.display.flip()
    pygame.time.wait(100)

pygame.quit()
