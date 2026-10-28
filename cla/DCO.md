# Developer Certificate of Origin (DCO) — Co-op SOC-in-a-Box
#
# Co-op SOC-in-a-Box adopts the same lightweight, permissive contribution
# mechanism used by the Linux Kernel and most permissive-licence OSS projects.
#
# By checking the "Signed-off-by" box (or running `git commit -a -s`), you certify
# that you agree to the terms below. The `Signed-off-by:` line certifies agreement
# with these conditions.

## Developer Certificate of Origin
```
By making a contribution to this project, I certify that:

  (a) The contribution was created in whole or in part by me and I have the
      right to submit it under the open-source license indicated by the repo's
      LICENSE/NOTICE (Apache-2.0 code, CC-BY-4.0 docs/manifest/rule samples —
      see NOTICE), OR
  (b) The contribution is based on previous work that, to the best of my
      knowledge, is covered by an appropriate license and I have the right
      under that license to submit that work with modifications, and
      (c) The contribution was provided to me by a company's employer, and
      they represent that the contribution was created by an individual
      contributor under terms that permit such contributions under this
      project's DCO, OR
  (d) The contribution was made in a role that permitted such work.

  By making a contribution, I agree that any contribution submitted to a
  project is licensed to project maintainers under that project's license,
  and that no patent or copyright claim is or will be asserted by me or any
  employer. This is the DCO used by the Linux Kernel and most permissive
  open-source projects, and it is compatible with Apache-2.0's permissive
  patent grant.
```

## Why a DCO, not a corporate CLA
- **Lightweight.** No email signup, no separate agreement. You sign with a `Signed-off-by:`
  trailer you can add today. This is the most inclusive CLA model — it has the
  **lowest possible barrier** for the co-op operators and small OT shops we serve.

- **No encumbrance for co-ops.** The co-op may adopt, modify, and self-host the
  scaffold under Apache-2.0 (code) / CC-BY-4.0 (docs) with a permissive patent
  grant. The DCO protects the co-op by ensuring every human-contributor attests
  they have the right to contribute, so no future maintainer can turn that
  into a litigation claim.

- **Corporate contributions** may add a `Corporate-Signed-off-by:` line on an
  individual's behalf, or use `cla/DCO-CORP.md` (a corporate CLA — optional, for
  orgs with their own legal needs).

## To sign a commit
Make sure your git config is set, then `-s`-sign each commit:
```
git commit -a -s -m "my contribution; add a co-op config sample"
# ->  Signed-off-by: Your Name <you@example.com>
git commit -a -s -m "corporate contribution on behalf of Acme Utility, LLC"
#    Signed-off-by: Your Name <you@example.com>
#    Corporate-Signed-off-by: Acme Utility, LLC <legal@acme-utility.com>
```

## Corporate CLA (optional)
`cla/DCO-CORP.md` templates a corporate CLA for orgs that need it. It is NOT
required for small co-ops or individual contributors — the individual `Signed-off-by:`
is all that's asked. The corporate form is there for larger orgs that have their
own policies.
