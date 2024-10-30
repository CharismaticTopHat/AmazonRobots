import pygame

from pygame.locals import *

# Cargamos las bibliotecas de OpenGL
from OpenGL.GL import *
from OpenGL.GLU import *
from OpenGL.GLUT import *

screen_width = 900
screen_height = 600

#Variables para dibujar los ejes del sistema
X_MIN=-500
X_MAX=500
Y_MIN=-500
Y_MAX=500
#Dimension del Plano
DimBoard = 200

# Archivos propios
from OpMat import OpMat
from Robot import Robot
from Box import Box

import requests

URL_BASE = "http://localhost:8000"
r = requests.post(URL_BASE+ "/simulations", allow_redirects=False)
datos = r.json()
print(datos)
LOCATION = datos["Location"]

coordsCars = []
coordsBoxes = []
coordsStorages = []

cars = datos["cars"]
for car in cars:
    coordsCars.append([datos["cars"][car]["pos"][0]], datos["cars"][car]["pos"][1])

boxes = datos["boxes"]
for box in boxes:
    coordsBoxes.append([datos["boxes"][box]["pos"][0]], datos["boxes"][box]["pos"][1])
    
storages = datos["storages"]
for storage in storages:
    coordsStorages.append([datos["storages"][storage], datos["storages"][storage]["pos"][1]])
    

opera = OpMat()

robots = []
packages = []
boxPiles = []

for car in cars: 
    num = str(car)
    r = Robot(opera)
    robots.append(r+num)
    
for box in boxes:
    num = str(box)
    b = Box(opera)
    packages.append(b+num)

for storage in storages:
    num = str(storage)
    s = Box(opera)
    boxPiles.append(s.num)

pygame.init()

def Axis():
    glShadeModel(GL_FLAT)
    glLineWidth(3.0)
    #X axis in red
    glColor3f(1.0,0.0,0.0)
    glBegin(GL_LINES)
    glVertex2f(X_MIN,0.0)
    glVertex2f(X_MAX,0.0)
    glEnd()
    #Y axis in green
    glColor3f(0.0,1.0,0.0)
    glBegin(GL_LINES)
    glVertex2f(0.0,Y_MIN)
    glVertex2f(0.0,Y_MAX)
    glEnd()
    glLineWidth(1.0)
    
def display():
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT)
    #Se dibuja el plano gris
    glColor3f(0.3, 0.3, 0.3)
    glBegin(GL_QUADS)
    glVertex3d(-DimBoard, 0, -DimBoard)
    glVertex3d(-DimBoard, 0, DimBoard)
    glVertex3d(DimBoard, 0, DimBoard)
    glVertex3d(DimBoard, 0, -DimBoard)
    glEnd()
    
    for robot in robots:
        robot.setColor(1.0,1.0,1.0)
        robot.setScale(2)
        robot.render()
        response = requests.get(URL_BASE + LOCATION)
        datos = response.json()
        Rbts = datos["cars"]
        robot.translate(Rbts["pos"][0], Rbts["pos"][1])
    
    for package in packages:
        package.setColor(1.0,1.0,0.0)
        package.setScale(2)
        package.render()
        response = requests.get(URL_BASE + LOCATION)
        datos = response.json()
        Bxs = datos["boxes"]
        package.translate(Bxs["pos"][0], Bxs["pos"][1])  
        
opera.loadId()

def init():
    screen = pygame.display.set_mode(
        (screen_width, screen_height), DOUBLEBUF | OPENGL)
    pygame.display.set_caption("OpenGL: Triángulos")

    glMatrixMode(GL_PROJECTION)
    glLoadIdentity()
    gluOrtho2D(-450,450,-300,300)
    glMatrixMode(GL_MODELVIEW)
    glLoadIdentity()
    glClearColor(0,0,0,0)
    #OPCIONES: GL_LINE, GL_POINT, GL_FILL
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
            #r1.moveUp()
        if keys[pygame.K_DOWN]:
            pass
            #r1.moveDown()
        if keys[pygame.K_LEFT]:
            pass
            #r1.turnLeft()
        if keys[pygame.K_RIGHT]:
            pass
            #r1.turnRight()
    glClear(GL_COLOR_BUFFER_BIT)
    Axis()
    display()  
    pygame.display.flip()
    pygame.time.wait(100)

pygame.quit()