# LLAM4RT

This project is a concept from the "Consumer AI Edge Hackathon". My contribution involved implementing a Large Language Model (LLM) **on-device**, without internet access, based on the Llama 3 1B model. In 30 hours, I extended the ExecuTorch demo iOS app to support Retrieval-Augmented Generation (RAG), memory, and markdown. 

Despite having no experience in Swift, iOS app development, and limited experience with LLMs, I managed to achieve this small project, and our team at the hackathon was the only one to achieve a fully on device LLM.

Our team built a small dataset of the l'Orangerie museum in Paris (images and extensive text descriptions), and the app can answer questions about the museum, its history, and the paintings.

To run this model, you need a compiled `.pte` file of the model and the `.model` tokenizer, which are not included in this repository. For more information, refer to the [ExecuTorch repository](https://github.com/pytorch/executorch). You then need to link them to the app.

Special thanks to the PyTorch team for the ExecuTorch project and their support during the hackathon, especially:

- Mergen Nachin from Meta [@mergennachin](https://github.com/mergennachin)
- Xuan Son Nguyen from Hugging Face [@ngxson](https://github.com/ngxson)
- Guang Yang from Meta