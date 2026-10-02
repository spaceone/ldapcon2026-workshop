class FilterModule:
    DN_ESCAPES = [
        (r'\\', r'\5C'),
        (r'\,', r'\2C'),
        (r'\+', r'\2B'),
        (r'\=', r'\3D'),
    ]

    def filters(self):
        return {
            'dn2subject_ordered': self.dn2subject_ordered,
        }

    def dn2subject_ordered(self, dn):
        result = []

        escaped = dn
        for escape in self.DN_ESCAPES:
            escaped = escaped.replace(*escape)

        for rdn in escaped.split(','):
            r = {}
            for ava in rdn.split('+'):
                attr, value = ava.split('=', 1)
                attr = attr.strip().upper()
                if attr in r:
                    raise ValueError("Invalid multivalued rDN")
                r[attr] = value.strip()
            result.append(r)

        return reversed(result)
