# Invocat

A nondeterministic, generative programming language for aleatory text by C & M Antoun.
2017-10-01

## The language

Invocat is a language for randomly generating text from grammars, which take the form
of lists. The two principal affordances of the language are defining and referencing lists.

### Definitions and references

Suppose we need to come up with a scene for our Russian novel. The following Invocat
grammar, consisting of list definitions and references, describes some possible scenes:

    Scene :: A (Conflict) in the (Location)

    Conflict :: Laceration | Strain | Hex                   -- | Affliction
    Location :: Library | Drawing Room | Cottage | Atelier

In Invocat, lists are defined as a name followed by the `::` operator and a list of items
separated by vertical bars `|`. References to lists are made by placing the list name inside of
parentheses `( )`. Comments start with two hyphens `--` followed by a space and continue
to the end of a line.

Now that we have defined a grammar, we can generate examples from it,

    (Scene)

which might produce `A Strain in the Library` (eh), `A Hex in the Atelier` (no),
`A Laceration in the Drawing Room` (brilliant!), or any other combination.

Notice that items are defined as literals that can contain spaces. Lists
may be recursive:

    adj :: warm | fuzzed out | most impenetrable | abrasive | (adj), (adj)

The `::` list notation is useful for short lists, but Invocat provides two other ways to write
defintions that are suited to longer content: the `---` and the `===` lists.

The `---` style lets you put one item on each line. It is a name, underlined with at least three
hyphens `---` and items separated by newlines.

    object
    ------
    thought on an obscure subject
    musing
    reverberation of (something)
    memory of (something)
    drone

The `===` style allows you to work with much longer lines. It is
a name, underlined with at least three equals `===` and items separated by at least three
hyphens `---`. The items can contain newlines, but two consecutive newlines terminates
the list.

    something
    ===================================================
    A (adj) (object) at a most inopportune time, taking
    into account nothing of the present circumstances.
    ---------------------------------------------------
    Without any warning, a (adj), dull, (object)
    overtakes your senses and leaves you in a quite
    indescribable mood.
    ---------------------------------------------------
    How did it even happen? Sitting in the drawing room,
    a (adj) sensation, a (object), though without
    attachment.

### Weighting list items

Both of the long forms allow you to specify weights for items. Weights can be specified in
either frequency or die notation.

Frequency weighting is denoted by (optionally) preceding each item with a weight value
followed by at least two spaces. The following coin is three times as likely to turn up tails.

    weighted coin
    -------------
    1  heads
    3  tails

Die weighting is denoted a little bit differently. To use die weighting, precede the list name with
`dN` (where `N` is any natural number) followed by at least two spaces; and (optionally) precede
each item with a weight value followed by at least two spaces. The following goblin tactics
call for axe work half the time and the use of a firebomb one sixth of the time.

     d6  goblin tactics
    -------------------
    1-3  axe
    4-5  short bow
      6  firebomb!

Note that despite the die weighting, the list would still be referenced as `(goblin tactics)`.

### Other operators

Invocat also supports some other operators, the most useful of which allow you to remember
the result of a given reference and sample without replacement from a list.

#### Selection

The evaluating selection operator `<!` is a kind of definition, useful when you need to reuse
the result of a reference. For example, given some colors, we can remember one in particular:

    color :: mazarine | cochineal | tartrazine | chlorine
    certain color <! (color)

    It was a (certain color) radiance--the purest (certain color).

#### Draw

The draw operator `{ }` is similar to a regular reference `( )` except that it removes its value
from the list. It allows you to sample without replacement.

    The color of our order is {color}; why do you wear (color)?

    Is not {color} for the herbalists, {color} the cartographers \
    and {color} the astrologers?


## Language reference

...


## Usage

...
