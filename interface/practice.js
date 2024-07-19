import React from 'react';
import { createRoot } from 'react-dom/client';

// Write code here: 
const container = document.getElementById('container');  
const root = createRoot(container);
root.render(<h1>Hello world</h1>);


const gooseImg = (
    <img 
    src={goose} /> 
) 

if (coinToss() == 'heads') {
    img = <img src={pics.kitty} /> 
} elif (coinToss() == 'tails') {
    img = <img src={pics.doggy} />
} 

root.render() 

