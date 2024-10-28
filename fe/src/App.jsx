  import { Button, ButtonGroup, CheckboxField, SliderField, SwitchField } from '@aws-amplify/ui-react';
  import { useRef, useState } from 'react'

  import '@aws-amplify/ui-react/styles.css';

  function App() {
    let [location, setLocation] = useState("");
    let [gridSize, setGridSize] = useState(80);
    let [probability_of_spread, setProbability] = useState(100);
    let [simSpeed,setSimSpeed] = useState(2);
    let [boxes, setBoxes] = useState([]);
    let [cars, setCars] = useState([]);
    let [iterations, setIterations] = useState(0);
    let [burntPerc, setBurntPerc] = useState(0);
    let [number, setNumber] = useState(40);
    let [sliderGridSize, setSliderGridSize] = useState(80);
    let [south_wind_speed, setSouthWindSpeed] = useState(0);
    let [west_wind_speed, setWestWindSpeed] = useState(0);
    let [bigJumps, setBigJumps] = useState(false);

    const burntBoxes = useRef(null);
    const sizing = 12.5;
    const running = useRef(null);

    let setup = () => {
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
        setIterations(0);
        setBurntPerc(0);
      });
    }

    let handleStart = () => {
      burntBoxes.current = [];
      running.current = setInterval(() => {
        fetch("http://localhost:8000" + location)
        .then(res => res.json())
        .then(data => {
          let burnt = data["boxes"].filter(b => b.status == "delivered").length / data["boxes"].length;
          burntBoxes.current.push(burnt);
          setBoxes(data["boxes"]);
          setCars(data["cars"]);
          setIterations(prev => prev + 1);
          setBurntPerc((burnt * 100).toFixed(2));
        });
        }, 3000 / simSpeed);
    };

    let handleStop = () => {
      clearInterval(running.current);
    };
    let offset = ((sizing*sliderGridSize) - gridSize * 12) / 2;

    return (
      <>
        <ButtonGroup variation="primary">
          <Button onClick={setup}>Setup</Button>
          <Button onClick={handleStart}>Start</Button>
          <Button onClick={handleStop}>Stop</Button>
        </ButtonGroup>

        <SliderField label="Grid size" min={40} max={80} step={10}
          value={sliderGridSize} onChange={setSliderGridSize} />
        <SliderField label="Simulation speed" min={1} max={30}
          value={simSpeed} onChange={setSimSpeed} />
        <SliderField label="Spread Probability" min={0} max={100} step={1}
          value={probability_of_spread} onChange={setProbability} />
        <SliderField label="Number" min={10} max={100} step={10}
          value={number} onChange={setNumber} />
        <SliderField label="South-North Wind" min={-50} max={50} step={1}
          value={south_wind_speed} onChange={setSouthWindSpeed} />
        <SliderField label="West-East Wind" min={-50} max={50} step={1}
          value={west_wind_speed} onChange={setWestWindSpeed} />
        <SwitchField label="Big Jump"
          checked={bigJumps} onChange={(e) => setBigJumps(e.target.checked)} />
        <p>Iterations: {iterations}</p> 
        <p>Burnt boxes percentage: {burntPerc}%</p>
        
        <svg width={sizing * sliderGridSize} height={sizing * sliderGridSize} xmlns="http://www.w3.org/2000/svg" style={{backgroundColor:"white"}}>
  {
    // Líneas horizontales
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
    // Líneas verticales
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
  {
    boxes.map(box => (
      <image
        key={box["id"]}
        x={(box["pos"][0] - 1) * sizing} // Ajuste para que las posiciones inicien desde el borde
        y={(box["pos"][1] - 1) * sizing} // Ajuste para que las posiciones inicien desde el borde
        width={sizing}  // Tamaño de la imagen ajustado al tamaño de la celda
        height={sizing} // Alto ajustado al tamaño de la celda
        href={"./caja.png"} // Ruta a la imagen
      />
    ))
  }
  {
    cars.map(car => (
      <image
        key={car["id"]}
        x={(car["pos"][0] - 1) * sizing} // Ajuste para que las posiciones inicien desde el borde
        y={(car["pos"][1] - 1) * sizing} // Ajuste para que las posiciones inicien desde el borde
        width={sizing}  // Tamaño de la imagen ajustado al tamaño de la celda
        height={sizing} // Alto ajustado al tamaño de la celda
        href={"./vite.svg"} // Ruta a la imagen
      />
    ))
  }
</svg>


      </>
    )
  }

  export default App