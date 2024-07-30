# Stop the Nosana node when the current job finishes.
- Copy all the following for the Installer:
  - `wget -qO finishjob-installer.sh 'https://raw.githubusercontent.com/MachoDrone/Stop-Nosana-node-after-current-job-finishes/main/finishjob-installer.sh' && sudo bash finishjob-installer.sh`
  
  - Open a new TTY or Terminal Window
    - start with `./finishjob.sh`
    
View while Nosana node is waiting for job to finish.
  
  ![alt text](https://github.com/MachoDrone/Stop-Nosana-node-after-current-job-finishes/blob/da22dac54bdeb4499f00fbd40ec91b22ffdf77f1/Screenshot1-finishjob.png)
  
View after Nosana node is stopped. Easy to see across the room.
  
  ![alt text](https://github.com/MachoDrone/Stop-Nosana-node-after-current-job-finishes/blob/da22dac54bdeb4499f00fbd40ec91b22ffdf77f1/Screenshot2-finishjob.png)
  
Or download with: `wget https://raw.githubusercontent.com/MachoDrone/Stop-Nosana-node-after-current-job-finishes/main/finishjob.sh`
  
Then `chmod +x finishjob.sh`
