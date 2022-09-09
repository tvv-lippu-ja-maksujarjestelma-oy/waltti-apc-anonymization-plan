# Waltti-APC anonymization plan

<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->

- [Introduction](#introduction)
- [Mobility anonymization](#mobility-anonymization)
- [Problem statement](#problem-statement)
- [Solution approach](#solution-approach)
  - [Attack attempt: Knowing the random seed](#attack-attempt-knowing-the-random-seed)
  - [Attack attempt: Sampling one stop](#attack-attempt-sampling-one-stop)
  - [Attack attempt: Sampling a sequence of stops](#attack-attempt-sampling-a-sequence-of-stops)
  - [Attack attempt: Combine different formats with different intervals](#attack-attempt-combine-different-formats-with-different-intervals)
  - [Attack attempt: Small vehicle](#attack-attempt-small-vehicle)
  - [Attack attempt: Prams and bicycles](#attack-attempt-prams-and-bicycles)
- [Bibliography](#bibliography)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

## Introduction

This document describes the plan for the anonymization process of the
automatic passenger counting (APC) data of the
[Waltti-APC](https://github.com/tvv-lippu-ja-maksujarjestelma-oy/waltti-apc)
project. The process is depicted to both satisfy the curiosity of the
stakeholders and to enable scrutiny from anonymization experts.

The purpose of the Waltti-APC project is

1.  to collect APC data and to enable public transport planners to use
    it,
2.  to test different technologies for counting people and objects in
    the vehicles and
3.  to stream anonymized APC data for use in other public transport
    services.

The input data for the anonymization is the current object counts in the
public transport vehicles, e.g. the number of adults and children
currently onboard each bus. The input data is updated at each departure
from a stop.

The output of the anonymization process has the form of ordinal
categories from “empty” to “full” per vehicle. The anonymized data is
updated whenever new input is received or regularly and often.

Publishing the anonymized APC data enables trip planner and passenger
information services to use occupancy information. For example, the
occupancy levels of vehicles could alter the results of trip suggestion
algorithms. Likewise, directly informing the users of the occupancy
levels might affect their travel plans.

Initial publication of the anonymized data will likely happen using
[`OccupancyStatus`](https://gtfs.org/realtime/reference/#enum-occupancystatus)
of the [GTFS Realtime](https://gtfs.org/realtime/) standard. Utilizing
[`OccupancyEnumeration`](https://github.com/SIRI-CEN/SIRI/blob/d8141698e1f3b450a17f3c52b3c93019a3ed91a1/xsd/siri_model/siri_reference-v2.0.xsd#L627)
of the [SIRI](https://www.siri-cen.eu/) standard might be done later.

The flow of data between the subsystems involved in Waltti-APC
anonymization is visualized below for context. The focus of this plan is
highlighted with a box in the middle.

``` mermaid
flowchart TB
  %% Systems

  onboard("Onboard counting systems")
  originalgtfsrtsource("Existing GTFS Realtime source")
  combiner("Combiner")
  gtfsrtenhancer("GTFS Realtime enhancer")
  tripplanner("Trip planner")
  stopdisplay("Bus stop display")
  passenger("Passenger")

  %% Data

  countchange[/"Object count changes for each door of each vehicle,\nsee the example below"/]
  journeydetails[/"GTFS Realtime:\nVehicle journey details for each vehicle,\nincluding route and stop,\nexcluding OccupancyStatus"/]
  enhancedgtfsrt[/"GTFS Realtime including OccupancyStatus"/]
  tripsuggestion[/"Trip suggestions"/]
  visualoccupancy[/"Occupancy levels visualized"/]

  %% Elements in focus

  subgraph focus[" "]
    anonymizer("Anonymizer")
    currentcount[/"Current count of objects for each vehicle,\nreset to zero after each vehicle journey"/]
    anonymizedlevels[/"Anonymized occupancy levels per vehicle"/]
  end

  %% Edges

  onboard --> countchange
  countchange --> combiner
  originalgtfsrtsource --> journeydetails
  journeydetails --> combiner
  combiner --> currentcount
  currentcount --> anonymizer
  anonymizer --> anonymizedlevels
  anonymizedlevels --> gtfsrtenhancer
  gtfsrtenhancer --> enhancedgtfsrt
  enhancedgtfsrt --> tripplanner
  tripplanner --> tripsuggestion
  tripsuggestion --> passenger
  enhancedgtfsrt --> stopdisplay
  stopdisplay --> visualoccupancy
  visualoccupancy --> passenger

  %% Styling

  classDef system fill:#c5dee3,stroke:#000,stroke-width:1px,color:#000

  class onboard system
  class originalgtfsrtsource system
  class combiner system
  class adder system
  class anonymizer system
  class gtfsrtenhancer system
  class tripplanner system
  class stopdisplay system
  class passenger system

  classDef datatype fill:#fff,stroke:#000,stroke-width:1px,color:#000

  class countchange datatype
  class journeydetails datatype
  class countchangewithjourneydetails datatype
  class currentcount datatype
  class anonymizedlevels datatype
  class enhancedgtfsrt datatype
  class tripsuggestion datatype
  class visualoccupancy datatype

  classDef special fill:#f7f7f7,stroke:#000,stroke-width:3px

  class focus special
```

Here is an example message from an onboard counting system into the APC
backend:

``` json
{
  "APC": {
    "schemaVersion": "1-1-0",
    "countingSystemId": "3298a747-c434-4030-b6d7-ab803bd823d2",
    "messageId": "06e64ba5-e555-4e2f-b8b4-b57bc69e8b99",
    "tst": "2021-11-22T10:57:08.647Z",
    "vehiclecounts": {
      "countquality": "regular",
      "doorcounts": [
        {
          "door": "door1",
          "count": [
            {
              "class": "adult",
              "in": 3,
              "out": 1
            }
          ]
        },
        {
          "door": "door2",
          "count": [
            {
              "class": "adult",
              "in": 0,
              "out": 2
            },
            {
              "class": "pram",
              "in": 1,
              "out": 0
            }
          ]
        }
      ]
    }
  }
}
```

## Mobility anonymization

Mobility data describes the physical movements of individuals over time.
As the timestamped locations of people often reveal very private
information there is a dire need to anonymize such data before
publication. This is often hard as not only is the mobility data of a
person highly unique but the mobility data can be combined with other
datasets to reveal individuals.

Anonymity can be thought of as a continuum, as the inverse of the
likelihood that someone can be recognized from a dataset. The anonymity
of a dataset must be balanced with the utility of the data. The tradeoff
does not seem stable over time, either, as we might choose a level of
anonymity that will later become easier to break, for example when a new
technique or an unexpected third-party dataset becomes available.

Anonymizing mobility data per person has been shown to be infeasible
(Zang and Bolot 2011; Montjoye et al. 2013). Instead, anonymizing
mobility data by carefully mixing movements of many individuals might
achieve anonymity. Care must be taken, though, as there have been
successful re-identification attacks even for such aggregated mobility
data (Xu et al. 2017).

Fortunately for us, the positional data we get as input is restricted to
public transport stop locations. Also the timestamps lie between the
arrival and the departure time of the vehicles for each stop. Both of
these information types are public.

In addition, the onboard counting systems send onwards only the changes
in the number of objects in the vehicles and do not try to identify any
individuals.

So what could be individually identifying in the input data?

## Problem statement

Consider a rarely used bus stop X. On most weekdays at 11:15, outside of
the rush hour, Reetta boards a bus from stop X to commute to her shift
work. She always takes line 123. Very few people use line 123 from stop
X and Reetta is almost always the only one to do it at 11:15. At that
time the bus is also often quite empty.

Imagine Birgitta first learns Reetta’s routine by direct observation or
with access to another dataset. After learning Reetta’s pattern, with
access only to the object counts of the bus, Birgitta could predict with
high accuracy whether Reetta stepped on the bus on any given weekday.

That connection to a person makes the data from the onboard counting
systems personal information under the GDPR.

A straightforward method to get the occupancy level from the headcount
would be to split the capacity of each vehicle model into intervals and
map the headcount onto its respective interval.

For example, if the capacity of a vehicle is 78 people, we could devise
the following correspondence:

| Headcount interval | Resulting `OccupancyStatus` value |
|--------------------|-----------------------------------|
| \[0, 5\]           | `EMPTY`                           |
| \[6, 40\]          | `MANY_SEATS_AVAILABLE`            |
| \[40, 50\]         | `FEW_SEATS_AVAILABLE`             |
| \[50, 65\]         | `STANDING_ROOM_ONLY`              |
| \[65, 72\]         | `CRUSHED_STANDING_ROOM_ONLY`      |
| \[73, 78\]         | `FULL`                            |

However, while `OccupancyStatus` does not reveal the accurate headcount,
an increase in the ordinal occupancy level from `EMPTY` to
`MANY_SEATS_AVAILABLE` at stop X for line 123 at 11:15 on a weekday
could similarly easily reveal Reetta’s actions.

As that inference is simple and we expect Reetta’s situation to be
realistic, further anonymization should be done.

## Solution approach

We propose to achieve the necessary anonymization by simply making the
boundaries between the headcount intervals probabilistic. For example,
to look at a few headcount values of the previous table and the
resulting `OccupancyStatus` values, we could devise the following
transition between `EMPTY` and `MANY_SEATS_AVAILABLE`:

| Headcount | Probability of resulting `OccupancyStatus` value |
|-----------|--------------------------------------------------|
| 3         | 100 % `EMPTY`                                    |
| 4         | 80 % `EMPTY`, 20 % `MANY_SEATS_AVAILABLE`        |
| 5         | 60 % `EMPTY`, 40 % `MANY_SEATS_AVAILABLE`        |
| 6         | 40 % `EMPTY`, 60 % `MANY_SEATS_AVAILABLE`        |
| 7         | 20 % `EMPTY`, 80 % `MANY_SEATS_AVAILABLE`        |
| 8         | 100 % `MANY_SEATS_AVAILABLE`                     |

Here the transition interval is \[3, 7\] i.e. 5 values wide. Care must
be taken in choosing the transition interval. The wider the transition
interval, the harder it becomes to guess the headcount that caused a
change in `OccupancyStatus` and thus the stronger the anonymity. The
narrower the transition interval, the more accurate and useful the
`OccupancyStatus` value is.

We will write a more rigorous description for this anonymization sketch
later.

Let’s look at some re-identification attacks a curious GTFS Realtime
listener could come up with.

### Attack attempt: Knowing the random seed

If an attacker knows the random seed used in the anonymizer, they could
break some of the anonymity over time as they could try to infer the
headcount from the `OccupancyStatus` values.

Thus we treat the random seed as a secret.

### Attack attempt: Sampling one stop

If an attacker gets the anonymizer to repeatedly sample the
`OccupancyStatus` value derived from the same headcount, they could
accurately infer the headcount from the shape of the distribution for
any `OccupancyStatus` value transition for any stop.

Thus we will sample the probability distribution only once for each
departure from a stop or passing of a stop.

### Attack attempt: Sampling a sequence of stops

If an attacker has found a long sequence of stops on a public transport
line, each stop having a very predictable usage pattern similar to
Reetta’s situation, the attacker could get many samples from the few
headcount scenarios. That might allow the attacker to infer the observed
headcounts accurately.

We find this scenario unrealistic and ignore it.

### Attack attempt: Combine different formats with different intervals

If a SIRI API is released using different headcount or transition
intervals than the GTFS Realtime API, an attacker could listen to both
APIs to infer the correct headcount.

We make sure that each API uses a subset of the same headcount and
transition intervals.

### Attack attempt: Small vehicle

If the vehicle capacity is low, say 15, the transition intervals cannot
be large. Thus either the anonymity or the usefulness of the
`OccupancyStatus` is severely reduced.

We must choose a suitable balance or not release occupancy levels for
small vehicles at all.

### Attack attempt: Prams and bicycles

GTFS Realtime does not have a field for the current number of prams in
the vehicles. However, the public transport authorities expect that many
passengers wish to know about current pram space availability before
their trip.

At some point in the Waltti-APC project, we aim to publish the current
pram space availability via an extension to GTFS Realtime or SIRI.

However, there is space for at most 3 prams in a vehicle. Having space
for just 1 pram is not atypical.

If Reetta were to always travel with a pram, an attacker could infer
Reetta’s presence by observing the accurate pram count. The same problem
applies to bicycles.

Anonymizing numbers from 0 to 3 while retaining usefulness of the data
seems very hard. We plan to solve this later.

## Bibliography

<div id="refs" class="references csl-bib-body hanging-indent">

<div id="ref-de_montjoye_unique_2013" class="csl-entry">

Montjoye, Yves-Alexandre de, César A. Hidalgo, Michel Verleysen, and
Vincent D. Blondel. 2013. “Unique in the Crowd: The Privacy Bounds of
Human Mobility.” *Scientific Reports* 3 (1): 1376.
<https://doi.org/10.1038/srep01376>.

</div>

<div id="ref-xu_trajectory_2017" class="csl-entry">

Xu, Fengli, Zhen Tu, Yong Li, Pengyu Zhang, Xiaoming Fu, and Depeng Jin.
2017. “Trajectory Recovery From Ash: User Privacy Is NOT Preserved in
Aggregated Mobility Data.” In *Proceedings of the 26th International
Conference on World Wide Web*, 1241–50. Perth Australia: International
World Wide Web Conferences Steering Committee.
<https://doi.org/10.1145/3038912.3052620>.

</div>

<div id="ref-zang_anonymization_2011" class="csl-entry">

Zang, Hui, and Jean Bolot. 2011. “Anonymization of Location Data Does
Not Work: A Large-Scale Measurement Study.” In *Proceedings of the 17th
Annual International Conference on Mobile Computing and Networking -
MobiCom ’11*, 145. Las Vegas, Nevada, USA: ACM Press.
<https://doi.org/10.1145/2030613.2030630>.

</div>

</div>
