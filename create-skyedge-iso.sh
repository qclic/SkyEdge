#!/bin/bash
# dnf -y install isomd5sum syslinux genisoimage
openeuler_iso_url="https://mirrors.tuna.tsinghua.edu.cn/openeuler/openEuler-22.03-LTS-SP3/ISO/x86_64/openEuler-22.03-LTS-SP3-x86_64-dvd.iso"
name="SkyEdge"
version="1.0"
timestamp="$(date +%Y%m%d%H%M)"
label="${name}-${version}-x86_64"

download_iso() {
    if [ ! -f openEuler-22.03-LTS-SP3-x86_64-dvd.iso ]; then
        wget ${openeuler_iso_url}
    fi
}

edit_iso() {
    tmpdir=$(mktemp -d -p .)
    mount -v openEuler-22.03-LTS-SP3-x86_64-dvd.iso ${tmpdir}
    rm -rf isodir
    cp -a ${tmpdir} isodir
    umount -v ${tmpdir}

    mount -v isodir/images/efiboot.img ${tmpdir}
    sed -i -e "s/openEuler/${name}/g" \
      -e "s/22.03-LTS-SP3/${version}/g" \
      isodir/isolinux/isolinux.cfg \
      isodir/EFI/BOOT/grub.cfg \
      ${tmpdir}/EFI/BOOT/grub.cfg
    while ! umount -v ${tmpdir}; do
        sleep 3
    done

    rm -rfv ${tmpdir}
}

product_img() {
    mkdir -pv product/usr/share/anaconda/pixmaps/
    cp -v logo/sidebar-logo.png product/usr/share/anaconda/pixmaps/
    pushd product
    cat > .buildstamp << EOF
[Main]
Product=${name}
Version=${version}
BugURL=your distribution provided bug reporting tool
IsFinal=True
UUID=${timestamp}.x86_64
Variant=Server
[Compose]
Lorax=33.6-1
EOF
    find . | cpio -c -o --quiet | pigz -9c > ../isodir/images/product.img
    popd

    rm -rfv product
}

create_iso() {
    rm -rfv ${name}-*.iso
    mkisofs -J -T -U \
        -joliet-long \
        -allow-limited-size \
        -o ${name}-${version}.iso \
        -b isolinux/isolinux.bin \
        -c isolinux/boot.cat \
        -no-emul-boot \
        -boot-load-size 4 \
        -boot-info-table \
        -eltorito-alt-boot \
        -e images/efiboot.img \
        -no-emul-boot \
        -R \
        -graft-points \
        -A "${label}" \
        -V "${label}" \
        isodir
    isohybrid -u ${name}-${version}.iso
    implantisomd5 --force ${name}-${version}.iso
}

download_iso
edit_iso
product_img
create_iso

