import matplotlib.pyplot as plt
import difflib
from tabulate import tabulate
import sys

verbose = True
try:
    if sys.argv[1] == "verbose=False":
        verbose = False
except:
    pass


def circle_info(info: str):
    """
    Returns a set of values given a string in the format "xc,yc,r"
    """
    values = info.split(',')
    values[2] = values[2].replace('\n','')

    # Return the circle values as a set in the form (xc,yc,r)
    return (int(values[0],16), int(values[1],16), int(values[2],16))



def get_data(file_path):
    """
    Returns a 2D list containing all of the data retrived from the .txt file in file_path in the form
    [[(xc,yc,r),[list of (word_addr,nbyte) pairs]],..]
    """
    data = []
    with open(file_path,"r") as f:
        lines = f.readlines()
        data_idx = -1
        for line in lines:
            if ',' in line: # This must be the centre coord and radius information
                data.append([circle_info(line),[]])
                data_idx +=1
            else:
                data[data_idx][1].append(line.replace('\n',''))
    return data

def check_values(data):
    """
    Compares the word address values
    """
    expected_addresses = [] # Stores the values of expected word addresses in base 10 from the circle model
    circle_info = data[0]
    values = [] # Stores list of pairs of values in the form (word_addr,nbyte)
    for datum in data[1]:
        info = datum.split(' ')
        values.append(info[0])
    
    xc = circle_info[0]
    yc = circle_info[1]
    r = circle_info[2]

    PIXELS = 640

    # Circle model
    x = 0
    y = r
    e = r

    while (x<=y):
        expected_addresses.append(xc+x+PIXELS*(yc+y) >> 2)
        expected_addresses.append(xc+y+PIXELS*(yc+x) >> 2)
        expected_addresses.append(xc+y+PIXELS*(yc-x) >> 2)
        expected_addresses.append(xc+x+PIXELS*(yc-y) >> 2)
        expected_addresses.append(xc-x+PIXELS*(yc-y) >> 2)
        expected_addresses.append(xc-y+PIXELS*(yc-x) >> 2)
        expected_addresses.append(xc-y+PIXELS*(yc+x) >> 2) 
        expected_addresses.append(xc-x+PIXELS*(yc+y) >> 2)
        e = e-2*x
        x += 1
        if (e<0):
            e = e + 2*y
            y -=1

    # Lists to compare word address values obtained in base 16
    expected_addresses = [standardise(hex(value)) for value in expected_addresses]
    if verbose:
        print("given: "+str(len(values)) + " values in the simulation\n"+str(values))
        print("expected: "+str(len(expected_addresses)) + " values from the high level model\n"+str(expected_addresses))
    return expected_addresses,values

def standardise(hex_value: str):
    """
    Converts python's hex() string format into the format produced by the simulator
    """
    return "0"+hex_value[-4:]

def plot_circle(circle):
    """
    Plots the model circle expected by the Bresenham Circle Algorithm (without parallelism since this is high level code) and returns the list of points plotted
    """
    def plot_points(xc,yc,x,y):
        """
        Plots the quadrants onto the plot
        """    
        current_points = []
        current_points.append((xc+x,yc+y))
        current_points.append((xc+y,yc+x))
        current_points.append((xc+y,yc-x))
        current_points.append((xc+x,yc-y))
        current_points.append((xc-x,yc-y))
        current_points.append((xc-y,yc-x))
        current_points.append((xc-y,yc+x))
        current_points.append((xc-x,yc+y))
        points.extend(current_points)
        for point in current_points:
            plt.plot(point[0],point[1],'o',color='green')
    
    points = []

    # Plot the circle in pyplot given (xc, yc, r) using the Bresenham Circle Algorithm
    xc = circle[0]
    yc = circle[1]
    r = circle[2]

    x = 0
    y = r
    e = r
    plot_points(xc,yc,x,y)
    while (x<y):
        plot_points(xc,yc,x,y)
        e = e - 2*x
        x +=1
        if (e < 0):
            e = e + 2*y
            y -=1
    return points

def parse_nbyte(nbyte):
    """
    Returns the increment to be added to word_addr % 640 based on nbyte to get the x coordinate
    """
    if nbyte == 'e':
        return 0
    elif nbyte == 'd':
        return 1
    elif nbyte == 'b':
        return 2
    elif nbyte == '7':
        return 3

def plot_output(output):
    """
    Plots the (x,y) coordinates based on (word_addr,nbyte) pairs received from the waveform simulation
    """
    values = [] # Stores list of pairs of values in the form (word_addr, nbyte)
    points = []
    for datum in output:
        data = datum.split(' ')
        values.append((data[0],data[1]))
    for value in values:
        word_addr = int(value[0],16) << 2
        increment = parse_nbyte(value[1])
        q, mod = divmod(word_addr,640)
        x = mod+increment
        y = q
        points.append((x,y))
        plt.plot(x,y,'*',color='red')
    return points

# Stores all the data values such that data[i][j] stores output de_addr values in list j from circle information stored in list i
data = get_data("output.txt")

with open("high_level_report.txt","w") as f:
    for idx,circle in enumerate(data):
        new_idx = str(idx+1)
        if new_idx == "24": # Ignore trying to calculate the massive circle
            continue
        xc = str(circle[0][0])
        yc = str(circle[0][1])
        r = str(circle[0][2])
        f.write("Circle "+new_idx+": with centre ("+xc+","+yc+")"+ " and radius "+r+"\n")
        expected_addresses, given_addresses = check_values(circle)
        expected_points = plot_circle(circle[0])
        given_points = plot_output(circle[1])
        sm=difflib.SequenceMatcher(None,expected_points,given_points)
        similarity = sm.ratio()
        if verbose:
            print("Similarity to expected model: ",similarity)
        f.write("Similarity to expected model: "+str(similarity)+"\n")

        if similarity > 0.8:
            f.write("Good similarity"+"\n")
        elif similarity > 0.6:
            f.write("Decent similarity"+"\n")
        else:
            f.write("Bad similarity"+"\n")
        f.write("\n")
        max = 0
        if len(expected_addresses) > len(given_addresses):
            max = len(expected_addresses)
        else:
            max = len(given_addresses)

        table_data = []
        for i in range(0,max):
            data_entry = []
            try:
                data_entry.append(expected_addresses[i])
            except:
                data_entry.append("")
            try:
                data_entry.append(given_addresses[i])
            except:
                data_entry.append("")
            try:
                data_entry.append(str(expected_addresses[i]==given_addresses[i]))
            except:
                data_entry.append("False")
            table_data.append(data_entry)
        f.write(tabulate(table_data,headers=["EXPECTED WORD_ADDR","GIVEN WORD_ADDR","EQUAL?"]))
        f.write("\n\n")
        if verbose:
            plt.title("Circle "+new_idx+": with centre ("+xc+","+yc+")"+ " and radius "+r+"\n")
            plt.show()
    
