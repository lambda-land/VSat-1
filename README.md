# Introduction
This repo is a fork of the VSAT project for the artifact submission to the
SPLC'20 conference, accompanying the following paper:

**Variational Satisfiability Solving**
Jeffrey Young, Eric Walkingshaw, and Thomas Thüm
_24th ACM International Systems and Software Product Line Conference (SPLC 2020)_

For an up to date version of the variational satisfiability solver see
[this](https://github.com/doyougnu/VSat) repository. For additional details on
performing the statistical analysis please see the
[Appendix](https://github.com/lambda-land/VSat-Papers/tree/master/SPLC2020)
repository

# Building VSAT from Source

## Dependencies

-   You will need to install the following:
    -   Haskell with GHC 8.6.x or greater
    -   cabal, version 1.12 or greater
    -   stack, version 2.3.x or greater
    -   z3, version 4.8.7 or greater

## Building from source without nix (default)

-   Install the dependencies listed above for your operating system, see the appendix and VSAT repositories for OS specific instructions
-   clone the VSAT repository:

    ```
    git clone git@github.com:doyougnu/VSat.git
    cd VSat
    ```
-   Navigate to the source code in the <span class="underline">haskell</span> directory and ensure that the following snippet is *commented*:

    ```
    cd haskell
    cat stack.yaml
    ...
    ## uncomment the following lines to tell stack you are in a nix environment
    # nix:
    #   enable: true
    #   pure: true
    #   packages: [ z3, pkgconfig, zlib ]
    ...
    ```
-   build the project using stack

    ```
    stack build
    ```
-   You can now run any of the analysis from the submission paper, please see the Appendix repository for specific invocations for each research question in the paper. You may also run the tool in a REPL via stack:

    ```
    stack ghci
    ...
    Ok, 21 modules loaded.
    Loaded GHCi configuration from /run/user/1729/haskell-stack-ghci/a8b1e3c4/ghci-script

    *Main Api CaseStudy.Auto.Auto CaseStudy.Auto.CompactEncode CaseStudy.Auto.Lang
     CaseStudy.Auto.Parser CaseStudy.Auto.Run Config Json Opts Parser Result Run
     SAT Server Utils VProp.Boolean VProp.Core VProp.Gen VProp.SBV VProp.Types>

    *Main Api CaseStudy.Auto.Auto CaseStudy.Auto.CompactEncode CaseStudy.Auto.Lang
     CaseStudy.Auto.Parser CaseStudy.Auto.Run Config Json Opts Parser Result Run
     SAT Server Utils VProp.Boolean VProp.Core VProp.Gen VProp.SBV VProp.Types> :set prompt "> "

    > :t sat
    sat :: (Resultable d, SAT (ReadableProp d)) => ReadableProp d -> IO (Result d)

    > :m + Data.Text

    > let prop = (bRef "a" ||| (bChc "AA" (bRef "b") (bRef "c")) :: ReadableProp Text)

    > sat prop
    Result ("b":=#F
    +--"__Sat":=("AA" and #T) or (not "AA" and #T)
    |  +--|
    |  +--"a":="AA" and #T
    +--"c":=not "AA" and #T
    ,UnSatResult (fromList []))

    > sat (bRef "a" &&& (bChc "AA" (bnot $ bRef "a") (bRef "c")) :: ReadableProp Text)
    Result ("a":=not "AA" and #T
    +--"__Sat":=not "AA" and #T
    +--"c":=not "AA" and #T
    ,UnSatResult (fromList [("AA" and #T,[])]))
    ...
    ```

## Building from source using nix

If you use `nix` or `nixOS` we provide several `*.nix` files to fully recreate the development environment of the paper, including pinning `nixpkgs` to the month of submission. Please see the appendix repository for more information. We recommend using stack to perform the build on `nix` systems. Using nix itself should also work but is untested. To build on a `nix` based system perform the following:

-   clone the VSAT repository:

    ```
    git clone git@github.com:doyougnu/VSat.git
    cd VSat
    ```
-   navigate to the tool in the <span class="underline">haskell</span> directory and Ensure that the following snippet is *uncommented*:

    ```
    cd haskell
    cat stack.yaml
    ...
    ## uncomment the following lines to tell stack you are in a nix environment
    nix:
      enable: true
      pure: true
      packages: [ z3, pkgconfig, zlib ]
    ...
    ```
-   build the project using stack

    ```
    stack build
    ```
-   You can now run any of the analysis from the submission paper, please see the Appendix repository for specific invocations for each research question in the paper. You may also run the tool in a REPL via stack:

    ```
    stack ghci
    ...
    Ok, 21 modules loaded.
    Loaded GHCi configuration from /run/user/1729/haskell-stack-ghci/a8b1e3c4/ghci-script

    *Main Api CaseStudy.Auto.Auto CaseStudy.Auto.CompactEncode CaseStudy.Auto.Lang
     CaseStudy.Auto.Parser CaseStudy.Auto.Run Config Json Opts Parser Result Run SAT
     Server Utils VProp.Boolean VProp.Core VProp.Gen VProp.SBV VProp.Types>

    *Main Api CaseStudy.Auto.Auto CaseStudy.Auto.CompactEncode CaseStudy.Auto.Lang
     CaseStudy.Auto.Parser CaseStudy.Auto.Run Config Json Opts Parser Result Run SAT
    Server Utils VProp.Boolean VProp.Core VProp.Gen VProp.SBV VProp.Types> :set prompt "> "

    > :t sat
    sat :: (Resultable d, SAT (ReadableProp d)) => ReadableProp d -> IO (Result d)

    > :m + Data.Text

    > let prop = (bRef "a" ||| (bChc "AA" (bRef "b") (bRef "c")) :: ReadableProp Text)

    > sat prop
    Result ("b":=#F
    +--"__Sat":=("AA" and #T) or (not "AA" and #T)
    |  +--|
    |  +--"a":="AA" and #T
    +--"c":=not "AA" and #T
    ,UnSatResult (fromList []))

    > sat (bRef "a" &&& (bChc "AA" (bnot $ bRef "a") (bRef "c")) :: ReadableProp Text)
    Result ("a":=not "AA" and #T
    +--"__Sat":=not "AA" and #T
    +--"c":=not "AA" and #T
    ,UnSatResult (fromList [("AA" and #T,[])]))
    ...
    ```
## Reproducing the data
All the data cited in the paper can be reproduced by running benchmarks provided
in this project. Run a benchmark using stack + gauge,e.g., `stack bench
vsat:auto --benchmark-arguments='+RTS -qg -A64m -AL128m -n8m -RTS --csv
output-file.csv`

Add a `csvraw` argument to get the bootstrapped averages _and_ the raw
measurements from gauge: `stack bench vsat:auto --benchmark-arguments='+RTS -qg
-A64m -AL128m -n8m -RTS --csv output-file.csv --csvraw raw-output.csv`

The available benchmarks are listed benchmark targets in `package.yaml` in the vsat Haskell project:
  - run the automotive dataset
    - `stack bench vsat:auto --benchmark-arguments='+RTS -qg -A64m -AL128m -n8m -RTS --csv output-file.csv'`
  - run the financial dataset
    - `stack bench vsat:fin --benchmark-arguments='+RTS -qg -A64m -AL128m -n8m -RTS --csv output-file.csv'`
  - run the core/dead on auto
    - `stack bench vsat:auto-dead-core --benchmark-arguments='+RTS -qg -A64m -AL128m -n8m -RTS --csv output-file.csv'`
  - run the core/dead on fin
    - `stack bench vsat:fin-dead-core --benchmark-arguments='+RTS -qg -A64m -AL128m -n8m -RTS --csv output-file.csv'`
  - run variational model diagnostics on fin:
    - `stack bench vsat:fin-diag --benchmark-arguments='+RTS -qg -A64m -AL128m -n8m -RTS --csv output-file.csv'`
  - run variational model diagnostics on auto:
    - `stack bench vsat:auto-diag --benchmark-arguments='+RTS -qg -A64m -AL128m -n8m -RTS --csv output-file.csv'`

To retrieve the counts of sat vs unsat models you can count the disjuncted
clauses in the resulting variational model. The numbers cited in the paper come
from a branch which altered the benchmark source code to count the outputs of
the solver. This branch is called `SatUnsatCounting` in the vsat project github
cited above.

We make all scripts to generate plots in the paper and perform the data analysis
available in the `haskell/statisticsScripts` folder, in addition we provide
`RMarkdown` files describing the statistical analysis in a step-by-step manner
in the
[Appendix](https://github.com/lambda-land/VSat-Papers/tree/master/SPLC2020)
repository.

#### Processing data
We make available a julia script called `parseRaw.jl` to process the `csv` files
from the benchmarking. You'll have to edit the input and output of it by hand.
If you run it on data generated with `csvraw` you'll need to change `:Name` to
`:name` or vice versa. We do not provide a `.nix` file for the julia script
because at the time of this writing Julia has not solidified their packaging
process enough for `nix` to reproduce it in a pure, functional way. If needed,
the `csv`s can be parsed in `R` or your language of choice.

## Installing Stack

### Windows
The Haskell Stack tool provides a 64-bit installer you can find
[here](https://docs.haskellstack.org/en/stable/README/#how-to-install). I'm
avoiding linking to it so that this page stays in sync with the latest stack
version.

### Mac
On any Unix system you can simple run:
```
curl -sSL https://get.haskellstack.org/ | sh
```

The more popular way is just to use homebrew:
```
brew install stack
```

### Linux Distros

#### Ubuntu, Debian
Stack will definitely be in a package that you can grab, although the official
packages tend to be out of data. You'll need to run the following to ensure you
have all required dependencies:

```
sudo apt-get install g++ gcc libc6-dev libffi-dev libgmp-dev make xz-utils zlib1g-dev git gnupg
```

and now you can run:

```
sudo apt-get install haskell-stack
```

and now make sure you are on the latest stable release:
```
stack upgrade --binary-only
```

#### CentOS, Fedora

Make sure you have the dependencies:

```
## swap yum for dnf if on older versions (<= 21)
sudo dnf install perl make automake gcc gmp-devel libffi zlib xz tar git gnupg
```

Now install stack

```
## CentOS
dnf install stack

## Fedora
sudo dnf copr enable petersen/stack ## enable the unofficial Copr repo
dnf install stack
```

and now make sure you upgrade stack to latest stable

```
## CentOS and Fedora
stack upgrade
```

#### NixOS
Stack is in `systemPackages`, so you can just add `stack` to that section of
your `configuration.nix` or you can run `nix-env -i stack` if you do things in
an ad-hoc manner. Using `stack` inside of nixOS is slightly more tricky than
non-pure distros. All you'll need to do is edit either the `stack.yaml` file
in the github repo and tell stack you are in a nix environment, like so:

```
## uncomment the following lines to tell stack you are in a nix environment
# nix:
  # enable: true
  # pure: false
  # packages: [ z3, pkgconfig ]
```

Notice that you'll need to pass in the extra packages for the tool. In this case
I'm using `z3` so I need to tell stack to look for it, and `pkgconfig` which you
should almost always pass in.

## Installing Haskell Using Stack
You just need to run the following:
```
stack setup # this will download and install GHC, and a package index
git clone <this-repo> ~/path/you/want/to/build/in && cd /path/you/want/to/build/in
stack build # this will build the exectuable, go get some coffee, trust me
```

## Running the VSAT solver
### Starting the local server
To run the local server you need to build the project and then execute the
binary that results from the build, like so:
```
cd /to/haskell/directory/
stack build                # build the binary
stack exec vsat            # execute the binary
```

on my system this looks like:

```
➜  haskell git:(master) ✗ pwd
/home/doyougnu/Research/VSat/haskell
➜  haskell git:(master) ✗ stack build

Warning: Specified pattern "README.md" for extra-source-files does not match any files
vsat-0.1.0.0: unregistering (local file changes: src/Server.hs)
vsat-0.1.0.0: configure (lib + exe)
Configuring vsat-0.1.0.0...
vsat-0.1.0.0: build (lib + exe)
Preprocessing library for vsat-0.1.0.0..
Building library for vsat-0.1.0.0..
[ 1 of 14] Compiling SAT              ( src/SAT.hs, .stack-work/dist/x86_64-linux-nix/Cabal-2.0.1.0/build/SAT.o )
...
Linking .stack-work/dist/x86_64-linux-nix/Cabal-2.0.1.0/build/vsat/vsat ...

vsat-0.1.0.0: copy/register
Installing library in /home/doyougnu/Research/VSat/haskell/.stack-work/install/x86_64-linux-nix/lts-11.14/8.2.2/lib/x86_64-linux-ghc-8.2.2/vsat-0.1.0.0-Aj9r5QEWrvTKTjvHnt9QFe
Installing executable vsat in /home/doyougnu/Research/VSat/haskell/.stack-work/install/x86_64-linux-nix/lts-11.14/8.2.2/bin
Registering library for vsat-0.1.0.0..

➜  haskell git:(master) ✗ stack exec vsat
Spock is running on port 8080               # server now running on localhost:8080
```

### Available routes
There are only 2 routes available at this time but it is trivially easy to add
more and I will do so upon request (open an issue on the repo). These are:

```
localhost:8080/sat                     # run the VSMT solver with default config
localhost:8080/satWith                 # run solver with custom config
```

The default config uses `z3` and turns on the most useful optimizations. These
optimizations are trivially some reordering to maximize sharing in the
variational expressions. You can view them in the `Opts.hs` file. If you want to
customize the configuration see the `Sending a Request` section.

### Sending a Request
To send a request I recommend using a helpful tool like
[postman](https://www.getpostman.com/), you can `cURL` if you really want. In
any case the tool expects an object with two fields, `settings`, and
`proposition` with `settings` being an optional field. I've just used Haskell's
generics to generate the JSON parser so it is tightly coupled to the solver AST,
this is open to change in the future but for right now it is sufficient. Here
are some explicit examples:

```
####### Request to localhost:8080/sat
{"settings":null,"proposition":{"tag":"LitB","contents":true}}

# Response
[
    {
        "model": "[There are no variables bound by the model.]"
    }
]

######## the proposition
a ∨ kejtjbsjshvouk

# expands to in JSON
{
    "tag": "Opn",
    "contents": [
        "Or",
        [
            {
                "tag": "RefB",
                "contents": {
                    "varName": "a"
                }
            },
            {
                "tag": "RefB",
                "contents": {
                    "varName": "kejtjbsjshvouk"
                }
            }
        ]
    ]
}

# Request to localhost:8080/satWith
{
    "settings": {
        "seed": 1234,
        "solver": "Z3",
        "optimizations": [
            "MoveLeft",
            "Shrink"
        ]
    }
    ,"proposition": {
        "tag": "Opn",
        "contents": [
            "Or",
            [
                {
                    "tag": "RefB",
                    "contents": {
                        "varName": "a"
                    }
                },
                {
                    "tag": "RefB",
                    "contents": {
                        "varName": "kejtjbsjshvouk"
                    }
                }
            ]
        ]
    }
}

# Response
[
    {
        "model": "  a              = False :: Bool\n  kejtjbsjshvouk = False :: Bool"
    }
]
```

As you can see these propositions, once expanded in JSON, can get quite large.
Here is a non trivial example, for more examples check the examples folder:

```
# The prop
((-17 > 93.52511917955651) ∧ ((-6 < |pccfjtjnkhfapjwtopwwxym|) ↔ ((DD≺zgmpwfdv , vrkpyxv≻) ∧ bifdhcpwh))) ∧ pevwtpjw

# Expands to
{
    "settings": {
        "seed": 1234,
        "solver": "Z3",
        "optimizations": []
    },
    "proposition": {
        "tag": "Opn",
        "contents": [
            "And",
            [
                {
                    "tag": "Opn",
                    "contents": [
                        "And",
                        [
                            {
                                "tag": "OpIB",
                                "contents": [
                                    "GT",
                                    {
                                        "tag": "LitI",
                                        "contents": {
                                            "tag": "I",
                                            "contents": -17
                                        }
                                    },
                                    {
                                        "tag": "LitI",
                                        "contents": {
                                            "tag": "D",
                                            "contents": 93.52511917955651
                                        }
                                    }
                                ]
                            },
                            {
                                "tag": "OpBB",
                                "contents": [
                                    "BiImpl",
                                    {
                                        "tag": "OpIB",
                                        "contents": [
                                            "LT",
                                            {
                                                "tag": "LitI",
                                                "contents": {
                                                    "tag": "I",
                                                    "contents": -6
                                                }
                                            },
                                            {
                                                "tag": "OpI",
                                                "contents": [
                                                    "Abs",
                                                    {
                                                        "tag": "Ref",
                                                        "contents": [
                                                            "RefI",
                                                            {
                                                                "varName": "pccfjtjnkhfapjwtopwwxym"
                                                            }
                                                        ]
                                                    }
                                                ]
                                            }
                                        ]
                                    },
                                    {
                                        "tag": "Opn",
                                        "contents": [
                                            "And",
                                            [
                                                {
                                                    "tag": "ChcB",
                                                    "contents": [
                                                        {
                                                            "dimName": "DD"
                                                        },
                                                        {
                                                            "tag": "RefB",
                                                            "contents": {
                                                                "varName": "zgmpwfdv"
                                                            }
                                                        },
                                                        {
                                                            "tag": "RefB",
                                                            "contents": {
                                                                "varName": "vrkpyxv"
                                                            }
                                                        }
                                                    ]
                                                },
                                                {
                                                    "tag": "RefB",
                                                    "contents": {
                                                        "varName": "bifdhcpwh"
                                                    }
                                                }
                                            ]
                                        ]
                                    }
                                ]
                            }
                        ]
                    ]
                },
                {
                    "tag": "RefB",
                    "contents": {
                        "varName": "pevwtpjw"
                    }
                }
            ]
        ]
    }
}

# The Response
[
    {
        "isSat": "Unsatisfiable"
    },
    {
        "\"DD\"": {
            "L": null,
            "R": null
        }
    }
]
```

Notice that the response is parameterized by the choice dimension `DD`. The `L`
tag corresponds to setting `DD` to `true`, and the `R` to the `false` branch.
