import math

from pygame.locals import *

# Cargamos las bibliotecas de OpenGL
from OpenGL.GL import *
from OpenGL.GLU import *
from OpenGL.GLUT import *

class Box:
    def __init__(self, op):
        self.points = [
            [-2.0, -2.0, 1.0], [2.0, -2.0, 1.0], [2.0,2.0,1.0],[-2.0,2.0,1.0]
            ]
        self.color = [1.0, 1.0, 1.0]
        #Apuntador a Operaciones Matriciales
        self.opera = op
        #Variables internas
        self.pos = [0.0,0.0, 1.0]
        self.delta_dir = [1.0,0.0,0.0]
        self.theta = 0
        self.scale = 3
        self.color = [1.0, 1.0, 1.0]
        self.remRotation = 0  
        self.delta_theta = 5
    
    def update(self):
        if self.remRotation > 0:
            self.theta += self.delta_theta
            self.remRotation -= 5
        self.pos = self.pos + self.delta_dir
        radians = math.radians(self.theta)
        self.delta_dir[0] = math.cos(radians)
        self.delta_dir[1] = math.sin(radians)
        
    def setColor(self, r, g, b):
        self.color = [r, g, b]
        glColor3f(r, g, b)
        
    def setScale(self, num):
        self.scale = num
    
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
        self.opera.push()
        self.opera.translate(self.pos[0], self.pos[1])
        self.opera.rotate(self.theta)
        self.opera.scale(self.scale, self.scale)
        pointsR = self.opera.mult_Points(pointsR)
        self.opera.pop()
        glColor3fv(self.color)
        
        for i in range(4):
            self.Bresenham(pointsR[i], pointsR[(i + 1) % 4]) 

        self.update()

                
    def turnRight(self):
        if self.remRotation == 0:
            self.remRotation = 90
            self.delta_theta = -5

    def turnLeft(self):
        if self.remRotation == 0:
            self.remRotation = 90
            self.delta_theta = 5
    
    def moveUp(self):
            self.pos[0] += self.delta_dir[0]
            self.pos[1] += self.delta_dir[1]

    def moveDown(self):
            self.pos[0] -= self.delta_dir[0]
            self.pos[1] -= self.delta_dir[1]
