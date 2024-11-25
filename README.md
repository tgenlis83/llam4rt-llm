# LLAM4RT

This repository showcases the concept we developed during the Paris "Consumer AI Edge Hackathon" in November 2024.

## Project Overview

Our team aimed to create a museum guide app capable of answering questions about a museum and its artwork — entirely on-device. To complement this functionality, we also implemented a YOLOv11 model to detect and recognize paintings within the museum. Although this model wasn’t fully integrated into the app by the submission deadline, it remains a key part of our concept.

https://github.com/user-attachments/assets/5185e502-5461-43fb-af43-f03a0a59b697

### Key Contributions

My primary contribution was implementing a **Large Language Model (LLM)** fully on-device, without requiring internet access. This implementation utilized the Llama 3 1B model and involved the following innovations:

- Extended the ExecuTorch demo iOS app to support:
  - **Retrieval-Augmented Generation (RAG)**
  - **Memory capabilities**
  - **Markdown support**
- All coding was done in **Swift**, a language I had no prior experience with.
- Delivered these results within 30 hours during the hackathon.

Another team member, Martin [@MartinMohammed](https://github.com/MartinMohammed), developed a dedicated interface for the app. Since I focused on the LLM integration, I built upon the ExecuTorch demo app as a foundation.

### Dataset Development and YOLOv11 Model

To power the app, our team built a custom dataset specifically for the **l'Orangerie Museum in Paris**. This involved visiting the museum in person to collect images and gather extensive text descriptions about its exhibits and paintings. The dataset was carefully crafted to provide detailed and accurate information about the museum's history, collections, and individual artworks.

The YOLOv11 model was developed to detect and recognize the paintings in real-time. While this functionality wasn’t fully integrated into the app at the hackathon, it is a promising component for future development. 

Special thanks to **Anand** [@anand83](https://github.com/anand83), **Luka** [@lukalafaye](https://github.com/lukalafaye), and **Nossa** [@nossa-y](https://github.com/nossa-y) for their exceptional work on both the YOLOv11 detection model and the dataset creation.

### Achievement

Our team was the only one among 24+ teams to successfully implement a fully on-device LLM solution. This functionality allowed the app to answer questions about the l'Orangerie museum in Paris, providing users with rich, contextual responses based on our custom dataset.

## Requirements

To run the model, you will need:
- A compiled `.pte` file of the model.
- The corresponding `.model` tokenizer.

These files are not included in this repository. Please refer to the [ExecuTorch repository](https://github.com/pytorch/executorch) for guidance on obtaining and linking these resources to the app.

## Acknowledgments

Special thanks to the PyTorch team for their **ExecuTorch project** and exceptional support during the hackathon. We are especially grateful to:

- **Mergen Nachin** (Meta) [@mergennachin](https://github.com/mergennachin)
- **Xuan Son Nguyen** (Hugging Face) [@ngxson](https://github.com/ngxson)
- **Guang Yang** (Meta)

Their guidance and encouragement were instrumental in helping us bring this concept to life.
