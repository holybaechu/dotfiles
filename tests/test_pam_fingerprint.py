import ctypes
import ctypes.util
from pathlib import Path
import tempfile
import unittest


SOURCE = Path(__file__).resolve().parents[1] / 'system/linux/pam-fingerprint'
SDDM_SOURCE = SOURCE.with_name('pam-sddm')
CONVERSATION = ctypes.CFUNCTYPE(ctypes.c_int, ctypes.c_int, ctypes.c_void_p,
                               ctypes.c_void_p, ctypes.c_void_p)


class PamConversation(ctypes.Structure):
    _fields_ = [('conv', CONVERSATION), ('appdata_ptr', ctypes.c_void_p)]


class FingerprintAuthenticationTest(unittest.TestCase):
    """Exercise PAM routing with mock methods, without credentials or hardware."""

    @classmethod
    def setUpClass(cls):
        library = ctypes.util.find_library('pam')
        if not library:
            raise unittest.SkipTest('Linux-PAM is not installed')
        cls.pam = ctypes.CDLL(library)
        if not hasattr(cls.pam, 'pam_start_confdir'):
            raise unittest.SkipTest('Linux-PAM lacks isolated configuration support')
        cls.pam.pam_start_confdir.argtypes = [
            ctypes.c_char_p, ctypes.c_char_p, ctypes.POINTER(PamConversation),
            ctypes.c_char_p, ctypes.POINTER(ctypes.c_void_p),
        ]
        cls.pam.pam_authenticate.argtypes = [ctypes.c_void_p, ctypes.c_int]
        cls.pam.pam_end.argtypes = [ctypes.c_void_p, ctypes.c_int]

    def authenticate(self, password, fingerprint, locked=False, sddm=False):
        def module(success):
            return 'pam_permit.so' if success else 'pam_deny.so'

        rules = (SDDM_SOURCE if sddm else SOURCE).read_text()
        for original, replacement in (
            ('pam_faillock.so preauth', module(not locked)),
            ('pam_unix.so try_first_pass', module(password)),
            ('pam_env.so', 'pam_permit.so'),
            ('pam_faillock.so authsucc', 'pam_permit.so'),
        ):
            rules = rules.replace(original, replacement)
        with tempfile.TemporaryDirectory(prefix='pam-fingerprint-test-') as directory:
            root = Path(directory)
            marker = root / 'fingerprint-attempted'
            if sddm:
                scanner = root / 'scanner.sh'
                scanner.write_text(f': > "{marker}"\nexit {0 if fingerprint else 1}\n')
                fingerprint_module = f'pam_exec.so quiet /usr/bin/sh {scanner}'
            else:
                fingerprint_module = module(fingerprint)
            rules = rules.replace('pam_fprintd.so max-tries=3 timeout=10', fingerprint_module)
            (root / 'test').write_text('auth substack dotfiles-fingerprint\n')
            (root / 'dotfiles-fingerprint').write_text(rules)
            (root / 'system-auth').write_text(
                'auth required pam_permit.so\n'
                f'auth [success=1 default=bad] {module(password)}\n'
                'auth [default=die] pam_deny.so\n'
                'auth required pam_permit.so\n'
            )
            # Unexpected conversation requests fail instead of prompting.
            callback = CONVERSATION(lambda *_: 19)  # PAM_CONV_ERR
            conversation = PamConversation(callback, None)
            handle = ctypes.c_void_p()
            result = self.pam.pam_start_confdir(
                b'test', b'pam-test-user', ctypes.byref(conversation),
                directory.encode(), ctypes.byref(handle),
            )
            self.assertEqual(result, 0, 'Could not initialize isolated PAM')
            try:
                result = self.pam.pam_authenticate(handle, 0)
                self.fingerprint_attempted = marker.exists()
                return result
            finally:
                self.pam.pam_end(handle, result)

    def test_failed_scan_falls_back_to_password(self):
        self.assertEqual(self.authenticate(password=True, fingerprint=False), 0)

    def test_fingerprint_alone_succeeds(self):
        self.assertEqual(self.authenticate(password=False, fingerprint=True), 0)

    def test_invalid_credentials_are_rejected(self):
        self.assertNotEqual(self.authenticate(password=False, fingerprint=False), 0)

    def test_fingerprint_does_not_bypass_account_lock(self):
        self.assertNotEqual(self.authenticate(password=False, fingerprint=True, locked=True), 0)

    def test_sddm_password_skips_fingerprint(self):
        self.assertEqual(self.authenticate(password=True, fingerprint=False, sddm=True), 0)
        self.assertFalse(self.fingerprint_attempted)

    def test_sddm_fingerprint_alone_succeeds(self):
        self.assertEqual(self.authenticate(password=False, fingerprint=True, sddm=True), 0)
        self.assertTrue(self.fingerprint_attempted)

    def test_sddm_rejects_invalid_credentials(self):
        self.assertNotEqual(self.authenticate(password=False, fingerprint=False, sddm=True), 0)

    def test_sddm_password_does_not_bypass_account_lock(self):
        self.assertNotEqual(self.authenticate(password=True, fingerprint=False, locked=True, sddm=True), 0)


if __name__ == '__main__':
    unittest.main()
