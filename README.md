# swsmith.cc

This is my personal website & also a blog with lots of info on AWS, HPC and ParallelCluster.

To build locally:

0. Clone Repo

```bash
git clone https://github.com/sean-smith/swsmith.cc.git
git submodule init && git submodule update
```

1. Install Hugo

```bash
brew install hugo
```

2. Then build & preview

```bash
hugo serve -D
```

Preview at http://localhost:1313/