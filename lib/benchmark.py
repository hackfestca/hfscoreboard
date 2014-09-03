import time

class benchmark():
    _flags = []
    _autoPrint = False

    def __init__(self,autoPrint=None):
        if autoPrint:
            self._autoPrint = autoPrint
        
    def flag(self,name):
        self._flags.append([name,time.time()])
        if self._autoPrint and len(self._flags) > 1:
            self.printLastResult()
    
    def printLastResult(self):
        diff = self._flags[-1][1] - self._flags[-2][1]
        print(self._flags[-1][0] + ' = ' + str(diff))

    def printResults(self):
        for i in range(0,len(self._flags)-1):
            diff = self._flags[i+1][1] - self._flags[i][1]
            print(self._flags[i+1][0] + ' = ' + str(diff))
            

    
