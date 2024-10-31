import { Button, ButtonGroup, CheckboxField, SliderField, SwitchField } from '@aws-amplify/ui-react';
import { useRef, useState } from 'react';

import '@aws-amplify/ui-react/styles.css';

function App() {
  const [location, setLocation] = useState("");
  const [gridSize, setGridSize] = useState(80);
  const [probability_of_spread, setProbability] = useState(100);
  const [button, setButton] = useState(false); // Estado para manejar el botón de Setup
  const [simSpeed, setSimSpeed] = useState(2);
  const [boxes, setBoxes] = useState([]);
  const [cars, setCars] = useState([]);
  const [storages, setStorages] = useState([]);
  const [iterations, setIterations] = useState(0);
  const [deliveredPerc, setDeliveredPerc] = useState(0);
  const [number, setNumber] = useState(40);
  const [sliderGridSize, setSliderGridSize] = useState(80);
  const [south_wind_speed, setSouthWindSpeed] = useState(0);
  const [west_wind_speed, setWestWindSpeed] = useState(0);
  const [bigJumps, setBigJumps] = useState(false);
  const [showGrid, setShowGrid] = useState(false); // New state for grid visibility

  const deliveredBoxes = useRef(null);
  const sizing = 12.5;
  const running = useRef(null);

  // Define the orientation to angle mapping
  const orientationToAngle = {
    0: 0,   // Up
    1: -90,   // Left
    2: 180,    // Down
    3: 90      // Right
  };

  const setup = () => {
    setGridSize(sliderGridSize);
    fetch("http://localhost:8000/simulations", {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ 
        dim: [sliderGridSize, sliderGridSize],
        probability_of_spread: probability_of_spread,
        number: number,
        south_wind_speed: south_wind_speed,
        west_wind_speed: west_wind_speed,
        bigJumps: bigJumps
      })
    }).then(resp => resp.json())
    .then(data => {
      setLocation(data["Location"]);
      setBoxes(data["boxes"]);
      setCars(data["cars"]);
      setStorages(data["storages"]);
      setIterations(0);
      setDeliveredPerc(0);
    });
  };

  const handleStart = () => {
    deliveredBoxes.current = [];
    setButton(true);
    running.current = setInterval(() => {
      fetch("http://localhost:8000" + location)
      .then(res => res.json())
      .then(data => {
        let delivered = data["boxes"].filter(b => b.status === "delivered").length;
        deliveredBoxes.current.push(delivered);
        setBoxes(data["boxes"]);
        setCars(data["cars"]);
        setStorages(data["storages"]);
        setIterations(prev => prev + 1);
        setDeliveredPerc((number - delivered));
      });
    }, 300 / simSpeed);
  };

  const handleStop = () => {
    setButton(false);
    clearInterval(running.current);
  };

  const offset = ((sizing * sliderGridSize) - gridSize * 12) / 2;

  return (
    <>
      <ButtonGroup variation="primary">
        <Button onClick={setup} isDisabled={button}>Setup</Button>
        <Button onClick={handleStart} isDisabled={button}>Start</Button>
        <Button onClick={handleStop} isDisabled={!button}>Stop</Button>
      </ButtonGroup>

      <SliderField label="Grid size" min={40} max={80} step={10}
        value={sliderGridSize} onChange={setSliderGridSize} />
      <SliderField label="Simulation speed" min={1} max={30}
        value={simSpeed} onChange={setSimSpeed} />
      <SliderField label="Number of Boxes" min={10} max={100} step={10}
        value={number} onChange={setNumber} />

      {/* Add SwitchField to control grid visibility */}
      <SwitchField label="Show Grid" 
        checked={showGrid} onChange={(e) => setShowGrid(e.target.checked)} />

      <p>Iterations: {iterations}</p> 
      <p>Boxes Missing of Delivery: {deliveredPerc}</p>
      
      <svg width={sizing * sliderGridSize} height={sizing * sliderGridSize} xmlns="http://www.w3.org/2000/svg" style={{backgroundColor:"white"}}>
        {
          // Conditionally render horizontal and vertical lines for the grid
          showGrid && (
            <>
              {
                // Horizontal lines
                Array.from({ length: sliderGridSize + 1 }).map((_, i) => (
                  <line
                    key={`h-line-${i}`}
                    x1={0}
                    y1={i * sizing}
                    x2={sizing * sliderGridSize}
                    y2={i * sizing}
                    stroke="black"
                    strokeWidth="0.5"
                  />
                ))
              }
              {
                // Vertical lines
                Array.from({ length: sliderGridSize + 1 }).map((_, i) => (
                  <line
                    key={`v-line-${i}`}
                    x1={i * sizing}
                    y1={0}
                    x2={i * sizing}
                    y2={sizing * sliderGridSize}
                    stroke="black"
                    strokeWidth="0.5"
                  />
                ))
              }
            </>
          )
        }
        {
          boxes.map(box => (
            <image
              key={box.id}
              x={(box.pos[0] - 1) * sizing} // Adjust to start from the edge
              y={(box.pos[1] - 1) * sizing} // Adjust to start from the edge
              width={sizing}  
              height={sizing} 
              href={"./caja.png"} // Path to box image
            />
          ))
        }
        {
          cars.map(car => {
            // Calculate rotation angle
            const angle = orientationToAngle[car.orientation] || 0;

            // Calculate position
            const xPos = (car.pos[0] - 1) * sizing;
            const yPos = (car.pos[1] - 1) * sizing;

            // Calculate center for rotation
            const centerX = xPos + sizing / 2;
            const centerY = yPos + sizing / 2;

            return (
              <image
                key={car.id}
                x={xPos}
                y={yPos}
                width={sizing}
                height={sizing}
                href={"./vite.svg"} // Path to car image
                transform={`rotate(${angle}, ${centerX}, ${centerY})`}
              />
            );
          })
        }
        {
          storages.map(storage => (
            <image
              key={storage.id}
              x={(storage.pos[0] - 1) * sizing}
              y={(storage.pos[1] - 1) * sizing}
              width={sizing}
              height={sizing}
              href={storage.boxes <= "0" ? "./0.png" : storage.boxes <= "1" ? "./1.png" : storage.boxes <= "2" ? "./2.png" : storage.boxes <= "3" ? "./3.png" : storage.boxes <= "4" ? "./4.png" : "./5.png" } // Path to storage image
            />
          ))
        }
      </svg>
    </>
  );
}

export default App;
