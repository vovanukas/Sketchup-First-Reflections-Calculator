# SketchUp Ray Tracing Plugin

This repository hosts the SketchUp Ray Tracing Plugin that simulates ray reflections in a 3D environment. The plugin allows users to visualize sound reflections by casting rays from a selected surface within SketchUp models. It is designed to assist in architectural acoustic design by providing a quick and easy way to simulate sound-wave behavior in various environments.

https://github.com/user-attachments/assets/dbaf9d4a-9fc2-4865-8b36-f42991042ed0

## Project Overview

The core idea behind this project is to provide a functional tool within SketchUp, a popular 3D modeling software used by architects and designers. By utilizing the SketchUp Ruby API, this plugin enables reflection simulation based on ray paths, helping to visualize sound propagation and its interactions with surfaces.

### Key Features:

- Automatic ray casting from selected surfaces in the direction they are facing.
- Visualization of rays hitting obstacles in the defined environment.
- Visualization of reflections from the impact points.
- Easy interaction: Allow users to undo and clear simulations with minimal steps.
- Developed as a Minimum Viable Product (MVP) aimed at simplicity and real-time feedback.

## Getting Started

### Installation 

You can download the extension on the [Extensions Warehouse](https://extensions.sketchup.com/extension/4df1013f-58f9-4fe9-91f9-e3ba03920e9c/first-reflections-tool).

### Usage

1. Once the plugin is loaded, select any surface in your SketchUp model.
2. From the plugin menu, choose "Simulate Rays."
3. The plugin will visualize rays being projected outwards in the direction the surface is facing.
4. Rays that hit objects will be visualized along with their reflections.
5. Use the undo option to quickly remove simulations and refine your scenario.

### Development Process

This project follows an **Agile development** approach to allow for flexibility and iterative improvements:

- **Phase 1: Research & API Exploration**: Conducted initial research on SketchUp extension structures, reading the SketchUp API to discover key features and limitations that would shape the development of the MVP.
- **Phase 2-4: MVP Creation**: The first goal was to establish a Minimum Viable Product (MVP) that executes the basic user interaction with ray projection, hits, and reflection visualization.
- **Phase 5: Extension & Fine-Tuning**: Additional features were explored, such as efficient ray deletion/undo processes and multithreading options for larger projects.

### Testing & Debugging

- The extension was tested using the Ruby IDE **RubyMine**, which offers integration with GitHub for seamless code iteration tracking.
- Followed **Eneroth's method** for efficiently reloading SketchUp plugins during development.

## Future Improvements

There are several planned features and improvements for future versions:
- **Multithreading Support**: Experiment with multithreading to optimize reflections in cases with large numbers of components.
- **Sound Property Simulations**: Introduce more detailed acoustic simulation properties, beyond ray tracing for basic visualizations.
- **Expanded Customization**: Allow users to adjust ray properties, such as frequency or energy loss during reflections.
  
---

[Vladimiras Malyskinas - Music Technology Project.pdf](https://github.com/user-attachments/files/17396176/Vladimiras.Malyskinas.-.Music.Technology.Project.pdf)
