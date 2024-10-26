import pygame
import math
import numpy as np

from pygame.locals import *

class OpMat():
    def __init__(self):
        self.currentMatrix = np.identity(3)  
        self.matrixStack = []

    def translate(self, tx, ty):
        translationMatrix = [[1, 0, tx],
                             [0, 1, ty],
                             [0, 0, 1]]
        self.currentMatrix = np.matmul(self.currentMatrix, translationMatrix)
        
    def rotate(self, deg):
        radians = math.radians(deg)
        rotationMatrix = [[math.cos(radians), -math.sin(radians), 0],
                          [math.sin(radians), math.cos(radians), 0],
                          [0, 0, 1]]
        self.currentMatrix = np.matmul(self.currentMatrix, rotationMatrix)
        
    def scale(self, sx, sy):
        scaleMatrix = [[sx, 0, 0],
                       [0, sy, 0],
                       [0, 0, 1]]
        self.currentMatrix = np.matmul(self.currentMatrix, scaleMatrix)
        
    def mult_Points(self, points):
        pointsNew = [np.matmul(self.currentMatrix, point) for point in points]
        pointsNew = [point[:-1] for point in pointsNew]
        return pointsNew
    
    def loadId(self):
        if self.matrixStack:
            self.currentMatrix = self.matrixStack[-1].copy()  
        else:
            self.currentMatrix = np.identity(3)
    
    def push(self):
        self.matrixStack.append(self.currentMatrix.copy())
    
    def pop(self):
        if self.matrixStack:
            self.matrixStack.pop(0)
            if self.matrixStack:
                self.currentMatrix = self.matrixStack[-1]
            else:
                self.currentMatrix = np.identity(3) 
        else:
            print("Stack está vacío.")
