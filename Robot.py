import pygame
import numpy as np

from pygame.locals import *

# Cargamos las bibliotecas de OpenGL
from OpenGL.GL import *
from OpenGL.GLU import *
from OpenGL.GLUT import *

class Robot:
    def __init__(self, op):
        self.points = [
            #Main Body
            [-4.0, -2.0, 1.0], [4.0, -2.0, 1.0], [4.0,2.0,1.0],[-4.0,2.0,1.0],
            # Wheels (From Up-Left to Down-Right)
            [-4.0,3.0,1.0], [-2.0,3.0,1.0], [-2.0,4.0,1.0],[-4.0,4.0,1.0],
            [1.0,3.0,1.0], [3.0,3.0,1.0], [3.0,4.0,1.0], [1.0,4.0,1.0],
            [-4.0,-4.0,1.0], [-2.0,-4.0,1.0], [-2.0,-3.0,1.0], [-4.0,-3.0,1.0],
            [1.0,-4.0,1.0], [3.0,-4.0,1.0], [3.0,-3.0,1.0], [1.0,-3.0,1.0]
            ]
        self.color = [1.0, 1.0, 1.0]
        #Apuntador a Operaciones Matriciales
        self.opera = op
        #Variables internas
        self.pos = [0.0,0.0, 1.0]
        self.delta_dir = [1.0,0.0,0.0]
        self.theta = 0
        self.delta_theta = 1.0
        self.color = [1.0, 1.0, 1.0]
        self.scale = 1
    
    def update(self):
        self.op.matrixStack
        
        
    def setColor(self, r, g, b):
        self.color = [r, g, b]
        glColor3f(r, g, b)
    
    def Bresenham(self, p1, p2):
        #Trazado del punto inicial al punto final
        x0, y0 = p1[0], p1[1]
        x1, y1 = p2[0], p2[1]    

        # Verificiar si la inclinación es > o < a 45°
        if abs(y1 - y0) > abs(x1 - x0):
            dx = y1 - y0
            dy = x1 - x0
            x, y = y0, x0
            x1, y1 = y1, x1
            steep = True
        else:
            dy = y1 - y0
            dx = x1 - x0
            x, y = x0, y0
            steep = False

        # Determinar dirección del incremento
        signX = 1 if dx >= 0 else -1
        signY = 1 if dy >= 0 else -1

        dx = abs(dx)
        dy = abs(dy)

        # Variables de Bresenham
        Dinit = 2 * dy - dx
        E = 2 * dy
        NE = 2 * (dy - dx)

        glPointSize(5.0)
        glBegin(GL_POINTS)
        if steep:
            glVertex2f(round(y), round(x)) 
        else:
            glVertex2f(round(x), round(y))
        glEnd()

        for _ in range(int(dx)):
            if Dinit > 0:
                y += signY
                Dinit += NE
            else:
                Dinit += E
            x += signX
            
            glPointSize(5.0)
            glBegin(GL_POINTS)
            if steep:
                glVertex2f(y, x)
            else:
                glVertex2f(x, y)
            glEnd()
        
    def render(self):
        pointsR = self.points.copy()
        pointsR = self.opera.mult_Points(pointsR)
        glColor3fv(self.color)
        # Cuerpo principal
        for i in range(4):
            self.Bresenham(pointsR[i], pointsR[(i + 1) % 4]) 
        # Llantas
        wheel_offsets = [4, 8, 12, 16]
        for offset in wheel_offsets:
            for i in range(4):
                self.Bresenham(pointsR[offset + i], pointsR[offset + (i + 1) % 4])
                
    def turnRight(self):
        self.theta -= self.delta_theta  
        self.opera.rotate(self.theta) 

    def turnLeft(self):
        self.theta += self.delta_theta  
        self.opera.rotate(self.theta)  
    
    def moveUp(self):
        self.opera.translate(self.dir, 0)
        self.dir = self.dir + self.delta_dir

    def moveDown(self):
        self.opera.translate(self.dir, 0)
        self.dir = self.dir - self.delta_dir