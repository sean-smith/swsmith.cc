---
title: GPU Memory Calculator 🧮
description:
date: 2024-05-21
tldr: Quickly see how much memory your model needs
draft: false
tags: [nvidia, gpu, nccl, slurm, aws]
---


GPU Memory needs scale up based on the size of the model. To quickly calculate the memory required for a model you can use the calculators below.

> For inference memory required is typically 2 x the number of parameters, this is because each parameter is typically two bytes (FP16). So a 7B parameter model takes 14GB.  

> For training in mixed precision (FP16) it's typically 18x the number of parameters plus activations, this is typically 22-32x the number of parameters. So for a 7 B parameter model, you'll need at least 224GB of GPU memory.

These instance types have the following GPU memory:

| Instance | GPU  | GPU Memory |
|----------|------|------------|
| g5       | A10G | 24 GB      |
| p4d      | A100 | 40 GB      |
| p4de     | A100 | 80 GB      |
| p5       | H100 | 80 GB      |

The memory requirements will quickly exceed the memory available on a single instance type, hence the need to use parallelism technique which we'll cover in a later post.

## Inference

{{< rawhtml >}}
<p align="center">
    <script>
    function calculate() {
        var parameters = document.getElementById("parameters").value;
        var precision = document.getElementById("precision").value;
        var results = document.getElementById("results");
        results.innerHTML = `GPU Memory:  ${parameters * precision} GB`;
        return false;
    }
    </script>
    <form id="form" onsubmit="return calculate()" onchange="return calculate()">
        <div>
            Number of parameters in (B): 
            <input id="parameters" value="7" type="text"></input>
        </div>
        <div>
            Precision:
            <select id="precision">
                <option value="1">FP8</option>
                <option value="2">FP16</option>
                <option value="4">FP32</option>
            </select>
        </div>
    </form>
    
</p>


<div id='results'></div>

{{< /rawhtml >}}


## Training

{{< rawhtml >}}
<p align="center">
    <script>
    function calculate_tr() {
        var parameters = document.getElementById("parameters_tr").value;
        var precision = document.getElementById("precision_tr").value;
        var optimizer = document.getElementById("optimizer_tr").value;
        var results = document.getElementById("results_tr");
        results.innerHTML = `GPU Memory:  ${parameters * precision * optimizer} GB`;
        return false;
    }
    </script>
    <form onchange="return calculate_tr()" onsubmit="return calculate_tr()">
        <div>
            Number of parameters in (B): 
            <input id="parameters_tr" value="7" type="text"></input>
        </div>
        <div>
            Precision:
            <select id="precision_tr">
                <option value="1">FP8</option>
                <option value="2">FP16</option>
                <option value="4">FP32</option>
            </select>
        </div>
        <div>
            Optimizer:
            <select id="optimizer_tr">
                <option value="18">ADAM</option>
                <option value="22">SGD</option>
            </select>
        </div>
    </form>    
</p>

<div id='results_tr'></div>

{{< /rawhtml >}}