import { Button, ButtonGroup, CheckboxField, SliderField, SwitchField } from '@aws-amplify/ui-react';
import { useRef, useState } from 'react';

import '@aws-amplify/ui-react/styles.css';

function App() {
  // Estados para parámetros de simulación y visualización
  const [location, setLocation] = useState("");
  const [gridSize, setGridSize] = useState(80);  // Tamaño de la cuadrícula
  const [button, setButton] = useState(false); // Estado para el botón de "Setup"
  const [simSpeed, setSimSpeed] = useState(2);  // Velocidad de la simulación
  const [boxes, setBoxes] = useState([]);  // Estado para almacenar las cajas
  const [robots, setRobots] = useState([]);  // Estado para almacenar los coches
  const [storages, setStorages] = useState([]);  // Estado para los almacenamientos
  const [iterations, setIterations] = useState(0);  // Número de iteraciones
  const [deliveredPerc, setDeliveredPerc] = useState(0);  // Porcentaje de cajas entregadas
  const [number, setNumber] = useState(40);  // Número de cajas
  const [sliderGridSize, setSliderGridSize] = useState(80);  // Tamaño de la cuadrícula ajustable
  const [showGrid, setShowGrid] = useState(false); // Mostrar/ocultar cuadrícula

  const deliveredBoxes = useRef(null);
  const sizing = 12.5;  // Tamaño base para cálculo de posiciones
  const running = useRef(null);  // Control del estado de ejecución de la simulación

  // Mapeo de orientaciones a ángulos de rotación
  const orientationToAngle = {
    0: 0,   // Arriba
    1: -90,   // Izquierda
    2: 180,    // Abajo
    3: 90      // Derecha
  };

  // Configuración inicial de la simulación
  const setup = () => {
    setGridSize(sliderGridSize);
    fetch("http://localhost:8000/simulations", {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ 
        dim: [sliderGridSize, sliderGridSize],
        number: number,
      })
    }).then(resp => resp.json())
    .then(data => {
      setLocation(data["Location"]);  // Almacena la ubicación de la simulación en el backend
      setBoxes(data["boxes"]);
      setRobots(data["robots"]);
      setStorages(data["storages"]);
      setIterations(0);
      setDeliveredPerc(0);
    });
  };

  // Iniciar la simulación
  const handleStart = () => {
    deliveredBoxes.current = [];
    setButton(true);
    running.current = setInterval(() => {
      fetch("http://localhost:8000" + location)
      .then(res => res.json())
      .then(data => {
        let delivered = data["boxes"].filter(b => b.status === "delivered").length;  // Filtra cajas entregadas
        let stopRobots = data["robots"].filter(r => r.stopped == "moving").length;  // Filtra coches en movimiento
        deliveredBoxes.current.push(delivered);
        // Si no hay coches en movimiento, detiene la simulación
        if (stopRobots == 0) {
          handleStop();  // Detiene el intervalo y restablece el estado del botón
          return;
        }
        setBoxes(data["boxes"]);
        setRobots(data["robots"]);
        setStorages(data["storages"]);
        setIterations(prev => prev + 1);  // Incrementa las iteraciones
        setDeliveredPerc((number - delivered));  // Calcula el porcentaje de cajas no entregadas
      });
    }, 300 / simSpeed);
  };

  // Detener la simulación
  const handleStop = () => {
    setButton(false);
    clearInterval(running.current);
  };

  return (
    <>
      <ButtonGroup variation="primary">
        <Button onClick={setup} isDisabled={button}>Setup</Button>
        <Button onClick={handleStart} isDisabled={button}>Start</Button>
        <Button onClick={handleStop} isDisabled={!button}>Stop</Button>
      </ButtonGroup>

      {/* Controles de la simulación */}
      <SliderField label="Tamaño del Mapa" min={40} max={80} step={10}
        value={sliderGridSize} onChange={setSliderGridSize} isDisabled={button} />
      <SliderField label="Velocidad de Simulación" min={1} max={30}
        value={simSpeed} onChange={setSimSpeed} isDisabled={button} />
      <SliderField label="Número de Cajas" min={10} max={100} step={10}
        value={number} onChange={setNumber} isDisabled={button} />

      {/* Mostrar/ocultar cuadrícula */}
      <SwitchField label="Mostrar Cuadrícula" 
        checked={showGrid} onChange={(e) => setShowGrid(e.target.checked)} />

      <p>Iteraciones: {iterations}</p> 
      <p>Cajas Faltantes de Entrega: {deliveredPerc}</p>
      
      <svg width={sizing * sliderGridSize} height={sizing * sliderGridSize} xmlns="http://www.w3.org/2000/svg" style={{backgroundColor:"white"}}>
        {
          // Renderizado condicional de líneas horizontales y verticales para la cuadrícula
          showGrid && (
            <>
              {
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
          // Renderiza cajas en la cuadrícula
          boxes.map(box => (
            <image
              key={box.id}
              x={(box.pos[0] - 1) * sizing}
              y={(box.pos[1] - 1) * sizing}
              width={sizing}  
              height={sizing} 
              href={"./caja.png"}  // Ruta de la imagen de la caja
            />
          ))
        }
        {
          // Renderiza coches en la cuadrícula
          robots.map(robot => {
            const angle = orientationToAngle[robot.orientation] || 0;
            const xPos = (robot.pos[0] - 1) * sizing;
            const yPos = (robot.pos[1] - 1) * sizing;
            const centerX = xPos + sizing / 2;
            const centerY = yPos + sizing / 2;

            return (
              <image
                key={robot.id}
                x={xPos}
                y={yPos}
                width={sizing}
                height={sizing}
                href={"./vite.svg"}  // Ruta de la imagen del coche
                transform={`rotate(${angle}, ${centerX}, ${centerY})`}
              />
            );
          })
        }
        {
          // Renderiza almacenamientos en la cuadrícula con imágenes basadas en la cantidad de cajas
          storages.map(storage => (
            <image
              key={storage.id}
              x={(storage.pos[0] - 1) * sizing}
              y={(storage.pos[1] - 1) * sizing}
              width={sizing}
              height={sizing}
              href={storage.boxes <= "0" ? "./0.png" : storage.boxes <= "1" ? "./1.png" : storage.boxes <= "2" ? "./2.png" : storage.boxes <= "3" ? "./3.png" : storage.boxes <= "4" ? "./4.png" : "./5.png" }  // Ruta de la imagen de almacenamiento según cajas
            />
          ))
        }
      </svg>
    </>
  );
}

export default App;
