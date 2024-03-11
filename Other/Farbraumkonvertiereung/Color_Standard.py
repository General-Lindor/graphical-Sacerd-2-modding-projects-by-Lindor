import math

def lstr(e):
    x = str(e)
    y = repr(e)
    if len(x) > len(y):
        return x
    else:
        return y

def lprint(e):
    print(lstr(e))

def validate(val, name):
    if (not (isinstance(val, int) or isinstance(val, float))):
        raise TypeError(name + " must be float or int but is " + lstr(type(val)))
    if val < 0:
        raise ValueError(name + " must be greater than or equal to zero.")
    if val > 1:
        raise ValueError(name + " must be smaller than or equal to one.")

asixth = 1 / 6
athird = 1 / 3
ahalf = 1 / 2
twothirds = 2 / 3
fivesixths = 5 / 6

class rgb:
    def __init__(self, r, g, b):
        validate(r, "Red")
        validate(g, "Green")
        validate(b, "Blue")
        self.r = r
        self.g = g
        self.b = b
    
    def tohsv(self):
        if self.r > self.g:
            if self.g > self.b:
                maxval = self.r
                if math.isclose(maxval, 0):
                    return hsv(0, 0, 0)
                midval = self.g
                minval = self.b
                d = maxval - minval
                if math.isclose(d, 0):
                    h = 0
                else:
                    h = (midval - minval) / (d * 6)
            elif self.b > self.r:
                maxval = self.b
                if math.isclose(maxval, 0):
                    return hsv(0, 0, 0)
                midval = self.r
                minval = self.g
                d = maxval - minval
                if math.isclose(d, 0):
                    h = 0
                else:
                    h = twothirds + ((midval - minval) / (d * 6))
            else:
                maxval = self.r
                if math.isclose(maxval, 0):
                    return hsv(0, 0, 0)
                midval = self.b
                minval = self.g
                d = maxval - minval
                if math.isclose(d, 0):
                    h = 0
                else:
                    h = fivesixths + ((maxval - midval) / (d * 6))
        else:
            if self.b > self.g:
                maxval = self.b
                if math.isclose(maxval, 0):
                    return hsv(0, 0, 0)
                midval = self.g
                minval = self.r
                d = maxval - minval
                if math.isclose(d, 0):
                    h = 0
                else:
                    h = ahalf + ((maxval - midval) / (d * 6))
            elif self.b > self.r:
                maxval = self.g
                if math.isclose(maxval, 0):
                    return hsv(0, 0, 0)
                midval = self.b
                minval = self.r
                d = maxval - minval
                if math.isclose(d, 0):
                    h = 0
                else:
                    h = athird + ((midval - minval) / (d * 6))
            else:
                maxval = self.g
                if math.isclose(maxval, 0):
                    return hsv(0, 0, 0)
                midval = self.r
                minval = self.b
                d = maxval - minval
                if math.isclose(d, 0):
                    h = 0
                else:
                    h = asixth + ((maxval - midval) / (d * 6))
        s = d / maxval
        v = maxval
        return hsv(h, s, v)
    
    def tohsl(self):
        return self.tohsv().tohsl()
    
    def __str__(self):
        return str([self.r, self.g, self.b])
    
    def __repr__(self):
        return str(self)
    
    def isclose(self, other):
        if (math.isclose(self.r, other.r) and math.isclose(self.g, other.g) and math.isclose(self.b, other.b)):
            return True
        return False

class hsv:
    def __init__(self, h, s, v):
        validate(h, "Hue")
        validate(s, "Saturation")
        validate(v, "Value")
        self.h = h
        self.s = s
        self.v = v
    
    def torgb(self):
        maxval = self.v
        minval = maxval * (1 - self.s)
        if self.h >= fivesixths:
            midval = maxval - (((6 * self.h) - 5) * (maxval - minval))
            return rgb(maxval, minval, midval)
        elif self.h >= twothirds:
            midval = minval + (((6 * self.h) - 4) * (maxval - minval))
            return rgb(midval, minval, maxval)
        elif self.h >= ahalf:
            midval = maxval - (((6 * self.h) - 3) * (maxval - minval))
            return rgb(minval, midval, maxval)
        elif self.h >= athird:
            midval = minval + (((6 * self.h) - 2) * (maxval - minval))
            return rgb(minval, maxval, midval)
        elif self.h >= asixth:
            midval = maxval - (((6 * self.h) - 1) * (maxval - minval))
            return rgb(midval, maxval, minval)
        else:
            midval = minval + (6 * self.h * (maxval - minval))
            return rgb(maxval, midval, minval)
    
    def tohsl(self):
        l = self.v * (1 - (self.s * 0.5))
        if math.isclose(self.s, 0):
            return hsl(self.h, 0, l)
        if l < 0.5:
            s = (self.s) / (2 - self.s)
            return hsl(self.h, s, l)
        else:
            s = (self.s * self.v) / ((2 - (2 * self.v)) + (self.s * self.v))
            return hsl(self.h, s, l)
    
    def __str__(self):
        return str([self.h, self.s, self.v])
    
    def __repr__(self):
        return str(self)
    
    def isclose(self, other):
        if (math.isclose(self.h, other.h) and math.isclose(self.s, other.s) and math.isclose(self.v, other.v)):
            return True
        return False

class hsl:
    def __init__(self, h, s, l):
        validate(h, "Hue")
        validate(s, "Saturation")
        validate(l, "Lightness")
        self.h = h
        self.s = s
        self.l = l
    
    def torgb(self):
        return self.tohsv().torgb()
    
    def tohsv(self):
        if self.l < 0.5:
            t = (1 + self.s)
            s = (2 * self.s) / t
            v = t * self.l
            return hsv(self.h, s, v)
        else:
            t = (self.s - (self.s * self.l)) + self.l
            s = 2 * (1 - (self.l / t))
            v = t
            return hsv(self.h, s, v)
    
    def __str__(self):
        return str([self.h, self.s, self.l])
    
    def __repr__(self):
        return str(self)
    
    def isclose(self, other):
        if (math.isclose(self.h, other.h) and math.isclose(self.s, other.s) and math.isclose(self.l, other.l)):
            return True
        return False

def test():
    testvals = [0, 0.25, 0.3333333333, 0.5, 0.6666666666, 0.75, 1]
    success = True
    for r in testvals:
        for g in testvals:
            for b in testvals:
                partialsuccess = True
                x1 = rgb(r, g, b)
                y1 = x1.tohsv()
                z1 = x1.tohsl()
                x2 = y1.torgb()
                z2 = y1.tohsl()
                x3 = z1.torgb()
                y2 = z1.tohsv()
                if not (x1.isclose(x2) and x2.isclose(x3) and x3.isclose(x1)):
                    print(x1, x2, x3, "x")
                    partialsuccess = False
                    succcess = False
                if not (y1.isclose(y2)):
                    print(y1, y2, "y")
                    partialsuccess = False
                    succcess = False
                if not (z1.isclose(z2)):
                    print(z1, z2, "z")
                    partialsuccess = False
                    succcess = False
                if not partialsuccess:
                    print("")
    if success:
        input("Congratz! Your model passed the test, most likely it works!")
    else:
        input("There are issues with your model, it didn't pass the test!")

test()
"""
lprint(hsl(0.25, 1, 0.5))
lprint(hsl(0.25, 1, 0.5).torgb())
lprint(hsv(0.25, 1, 1))
lprint(hsv(0.25, 1, 1).torgb())

lprint(hsl(0.25, 0.75, 0.5))
lprint(hsl(0.25, 0.75, 0.5).torgb())
lprint(hsv(0.25, 0.75, 1))
lprint(hsv(0.25, 0.75, 1).torgb())
"""