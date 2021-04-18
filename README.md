# Brain Observatory Toolbox
A MATLAB toolbox for accessing and working with the neural recording public dataset releases from the Allen Brain Observatory resource \[1\]. 

**NOTE**: Releases for the current version (0.9) are a *working prototype* intended for evaluation. Feedback is encouraged and welcomed<sup>1</sup>

<sup>1. One or more channels to be established soon</sup>

## About the Allen Brain Observatory datasets
[Data releases](https://portal.brain-map.org/latest-data-release) from the Allen Brain Observatory include two datasets of neural activity recorded from the mouse visual cortex during visual stimulus presentation:  

| Dataset | Recording Type | Nickname | Details |
| --- | --- | --- | --- |
| Visual Coding Neuropixels \[2\] | Large-scale neural probe recordings | "ephys" (electrophysiology) | [details](https://portal.brain-map.org/explore/circuits/visual-coding-neuropixels) |
| Visual Coding 2P \[3\] | Two-photon calcium imaging | "ophys" (optical physiology) | [details](http://portal.brain-map.org/explore/circuits/visual-coding-2p) |


Technical white papers available for each dataset (see Details) provide detailed information describing the experiments, recordings, and computational pipelines. 

## About the Brain Observatory Toolbox (BOT) 
 
The Brain Observatory Toolbox (BOT) provides a uniform interface for users to conveniently access and work with these Visual Coding neural datasets. 

The BOT interface provides a tabular representation of available dataset items and an object representation of specific dataset items: 
![alt text](https://github.com/emeyers/Brain-Observatory-Toolbox/blob/backend/BOTDataSchematic.png?raw=true)

**Key Points:**
* Supported dataset items include experimental sessions (both 2P and Neuroxels datasets) as well as probes, channels, and units (for the Neuropixels dataset). 
* Tabular indexing or unique item identifiers can be used to select specific item(s) of interest from available items tables for item object creation. 
* Item object properties allow inspection and computation of direct, derived, and file-linked values associated to an item. 
* Values for item object properties involving extensive compute or file reading are computed "on demand". 
* Item object methods allow computations of values determined with additional user-specified arguments. 
* The BOT provides local caching of retrieved item information, object representations, and file contents, to provide the fastest possible initial and repeat performance within and across MATLAB sessions.

To preview the BOT in action: view the [Ephys Demo](https://viewer.mathworks.com/?viewer=live_code&url=https%3A%2F%2Fwww.mathworks.com%2Fmatlabcentral%2Fmlc-downloads%2Fdownloads%2F6aee4c33-d05e-4715-82ab-748f121adcad%2Fd61de411-5e28-4eba-8c36-c8b1df0435fc%2Ffiles%2FEphysDemo.mlx&embed=web) and/or the [Ophys Demo](https://viewer.mathworks.com/?viewer=live_code&url=https%3A%2F%2Fwww.mathworks.com%2Fmatlabcentral%2Fmlc-downloads%2Fdownloads%2F6aee4c33-d05e-4715-82ab-748f121adcad%2Fd61de411-5e28-4eba-8c36-c8b1df0435fc%2Ffiles%2FOphysDemo.mlx&embed=web).

## Installation Instructions

1. Download the `.zip` file from the latest GitHub release
2. Unzip via preferred system tool to desired local folder location
3. Open MATLAB 
4. Add root directory of the unzipped folder contents to the MATLAB path, in one of three ways: 
   1. Navigate to root directory in the *Current Folder* browser and select "Add to Path" from the right-click context menu<sup>1</sup>
   1. Open the *Set Path* dialog from the Environment section of the Home tab
   1. Call `addpath(<root directory location>)` in the Command Window
   
<sup>1. Use the "Selected Folders" option. The BOT is contained in the `+bot` [package folder](https://www.mathworks.com/help/matlab/matlab_oop/scoping-classes-with-packages.html). It is necessary and sufficient to add the package's parent folder to the path. </sup>

#### Required products
* MATLAB (R2021a)
* Image Processing Toolbox (if running the Visual Coding 2P demonstration `OphysDemo.mlx`)

## Getting started
Four MATLAB live scripts are provided to help get started: 

| Live Script(s) | About |
| --- | --- |
| `EphysDemo.mlx` and `OphysDemo.mlx` | Demonstrate simple representative neuroscientific analysis using the BOT | 
| `EphysTutorial.mlx` and  `OphysTutorial.mlx` | Step-by-step instruction and "under the hood" technical detail about using the BOT and the datasets | 
 
Or to get a fast first look yourself, enter the following commands in MATLAB: 
```
>> sessions = bot.fetchSessions('ephys'); 
>> head(sessions) 
>> session = bot.session(sessions(1,:))
>> methods(session) 
```
----
#### References

[1] Copyright 2016 Allen Institute for Brain Science. Allen Brain Observatory. Available from: [portal.brain-map.org/explore/circuits](http://portal.brain-map.org/explore/circuits).

[2] Copyright 2019 Allen Institute for Brain Science. Visual Coding Neuropixels Dataset. Available from: [portal.brain-map.org/explore/circuits/visual-coding-neuropixels](https://portal.brain-map.org/explore/circuits/visual-coding-neuropixels).

[3] Copyright 2016 Allen Institute for Brain Science. Visual Coding 2P Dataset. Available from: [portal.brain-map.org/explore/circuits/visual-coding-2p](http://portal.brain-map.org/explore/circuits/visual-coding-2p).

#### Acknowledgements

Initial engineering work was supported by the Foundation of Psychocultural Research and Sherman Fairchild Award at Hampshire College. 
