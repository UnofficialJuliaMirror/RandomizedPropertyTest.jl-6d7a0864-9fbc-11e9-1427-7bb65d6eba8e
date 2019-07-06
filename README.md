TODO
----

- print a more helpful error message in case of failure (property bla failed, inputs, evaluated, ...)
- actually add random tests... (use a PRNG for reproducibility)
- Allow setting variables to values, e.g "let x1 :: Float64, flag = true; f(x1, flag=flag); end"
- Catch and handle exceptions (show inputs, stacktrace, etc.)
- Write generators and special cases for all the things. (see how QuickCheck does it?)
- Custom specific generators for types for which a generic generator already exists (e. g. for ranges / prob. distributions for floats) (how does QuickCheck solve this?)
- parallel checking?
- more convenient syntax for many variables, like `@quickcheck (a+b)+c==a+(b+c) (a, b, c :: Int)`


- special cases for certain properties (like equality).
  Example:
      @quickcheck let a :: Float64, b :: Float64, c :: Float64; a + (b + c) == (a + b) + c; end
  should give something like:
      Property a + (b + c) == (a + b) + c does not hold for a = 1.0, b = 1.11e-16, c = 1.11e-16:
      1 + (1.11e-16 + 1.11e-16) == (1 + 1.11e-16) + 1.11e-16 evaluates to 1.000...02 == 1.0, which is false.
  (and similarly for >, <, etc.)
